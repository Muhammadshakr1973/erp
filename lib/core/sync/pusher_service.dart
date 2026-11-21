import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import 'pusher_ws_transport.dart';

final pusherServiceProvider = Provider<PusherService>((ref) {
  return PusherService(ref);
});

class PusherService {
  PusherChannelsFlutter? _pusher;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _usePureDartWs = false;

  final Map<String, List<void Function(Map<String, dynamic>)>> _listeners = {};
  final Set<String> _nativelySubscribedChannels = {};
  final Set<String> _inFlightSubscriptions = {};

  String? _serverKey;
  String? _serverCluster;
  Future<void>? _fetchFuture;
  Future<void>? _initFuture;

  // Pure-Dart WebSocket transport state (Linux/Windows/macOS/Web & fallback)
  PusherWsTransport? _wsTransport;
  StreamSubscription<String>? _wsMsgSub;
  StreamSubscription<void>? _wsCloseSub;
  Future<void>? _wsConnectFuture;
  String? _wsSocketId;
  Timer? _wsPingTimer;
  Timer? _wsReconnectTimer;
  Timer? _initRetryTimer;
  int _initRetryAttempt = 0;
  final Map<String, Timer> _channelRetryTimers = {};
  final Map<String, int> _channelRetryAttempts = {};
  int _wsReconnectAttempt = 0;
  bool _manuallyDisconnected = false;
  bool _hasConnectedBefore = false;
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  PusherService([Ref? _]);

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  Stream<void> get onReconnected => _reconnectController.stream;

  bool get _prefersPureDartWs =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _fetchPusherConfig() async {
    if (_serverKey != null &&
        _serverKey!.isNotEmpty &&
        _serverCluster != null &&
        _serverCluster!.isNotEmpty) {
      return;
    }

    if (_fetchFuture != null) {
      await _fetchFuture;
      return;
    }

    _fetchFuture = _fetchConfigFromServer();
    try {
      await _fetchFuture;
    } finally {
      _fetchFuture = null;
    }

    if (_serverKey != null &&
        _serverKey!.isNotEmpty &&
        _serverCluster != null &&
        _serverCluster!.isNotEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKey = prefs.getString('pusher_server_key')?.trim();
      final cachedCluster = prefs.getString('pusher_server_cluster')?.trim();
      if (cachedKey != null &&
          cachedKey.isNotEmpty &&
          cachedCluster != null &&
          cachedCluster.isNotEmpty) {
        _serverKey = cachedKey;
        _serverCluster = cachedCluster;
        debugPrint("Pusher config loaded from local cache fallback: key=$_serverKey");
      }
    } catch (_) {}
  }

  Future<void> _fetchConfigFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        debugPrint("Pusher Config Fetch: No auth token available yet.");
        return;
      }

      final response = await Dio().get(
        '${ApiClient.baseUrl}/broadcasting/config',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final key = response.data['key']?.toString().trim();
        final cluster = response.data['cluster']?.toString().trim();
        if (key != null &&
            key.isNotEmpty &&
            cluster != null &&
            cluster.isNotEmpty) {
          _serverKey = key;
          _serverCluster = cluster;
          debugPrint(
            "Pusher Config dynamically loaded from server: key=$_serverKey, cluster=$_serverCluster",
          );
          await prefs.setString('pusher_server_key', key);
          await prefs.setString('pusher_server_cluster', cluster);
        }
      }
    } catch (e) {
      debugPrint("Pusher Config Fetch Error: $e");
    }
  }

  Future<Map<String, dynamic>?> _authorizeChannel(
    String channelName,
    String socketId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        debugPrint("Pusher Authorizer: Failed - auth_token is null");
        return {'error': 'No auth token found'};
      }

      final response = await Dio().post(
        '${ApiClient.baseUrl}/broadcasting/auth',
        data: {
          'socket_id': socketId,
          'channel_name': channelName,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      if (response.data is String) {
        final decoded = jsonDecode(response.data as String);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      return {'error': 'Invalid auth response'};
    } catch (e) {
      debugPrint("Pusher Authorizer Request Error: $e");
      return {'error': e.toString()};
    }
  }

  void _decodeAndDispatchPayload(String? channelName, dynamic rawData) {
    if (channelName == null || rawData == null) return;
    try {
      Map<String, dynamic>? payload;
      if (rawData is Map) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is String && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      }

      if (payload == null) return;

      Map<String, dynamic> resolvedPayload = payload;
      if (payload.containsKey('data')) {
        final dataVal = payload['data'];
        if (dataVal is Map) {
          resolvedPayload = Map<String, dynamic>.from(dataVal);
        } else if (dataVal is String && dataVal.isNotEmpty) {
          try {
            final decodedNested = jsonDecode(dataVal);
            if (decodedNested is Map) {
              resolvedPayload = Map<String, dynamic>.from(decodedNested);
            }
          } catch (_) {}
        }
      }

      final listeners = _listeners[channelName];
      if (listeners != null && listeners.isNotEmpty) {
        for (final listener in List.of(listeners)) {
          try {
            listener(resolvedPayload);
          } catch (e) {
            debugPrint("Pusher Error in listener callback: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Pusher Error decoding payload: $e");
    }
  }

  Future<void> _ensureChannelSubscribedNatively(String channelName) async {
    if (!_isInitialized) return;
    if (_nativelySubscribedChannels.contains(channelName) ||
        _inFlightSubscriptions.contains(channelName)) {
      return;
    }

    if (_usePureDartWs) {
      if (!_isConnected || _wsSocketId == null || _wsTransport == null) {
        return;
      }
      _inFlightSubscriptions.add(channelName);
      try {
        final subData = <String, dynamic>{'channel': channelName};
        if (channelName.startsWith('private-') ||
            channelName.startsWith('presence-')) {
          final authResult = await _authorizeChannel(channelName, _wsSocketId!);
          final auth = authResult?['auth']?.toString();
          if (auth == null || auth.isEmpty) {
            debugPrint(
              "Pusher WS authorization failed for $channelName: $authResult",
            );
            _scheduleChannelRetry(channelName);
            return;
          }
          subData['auth'] = auth;
          if (authResult?['channel_data'] != null) {
            subData['channel_data'] = authResult!['channel_data'];
          }
        }

        _wsTransport?.send(
          jsonEncode({'event': 'pusher:subscribe', 'data': subData}),
        );
        _nativelySubscribedChannels.add(channelName);
        _channelRetryTimers.remove(channelName)?.cancel();
        _channelRetryAttempts.remove(channelName);
        debugPrint("Pusher WS Subscribed to: $channelName");
      } catch (e) {
        debugPrint("Pusher WS Subscription Error for $channelName: $e");
        _scheduleChannelRetry(channelName);
      } finally {
        _inFlightSubscriptions.remove(channelName);
      }
      return;
    }

    if (!_isConnected || _pusher == null) {
      debugPrint(
        "Pusher deferred native subscribe for $channelName until connected.",
      );
      return;
    }

    _inFlightSubscriptions.add(channelName);
    try {
      await _pusher?.subscribe(channelName: channelName);
      if (_isConnected) {
        _nativelySubscribedChannels.add(channelName);
        debugPrint("Pusher Subscribed to: $channelName");
      }
    } catch (e) {
      _nativelySubscribedChannels.remove(channelName);
      debugPrint("Pusher Subscription Error for $channelName: $e");
    } finally {
      _inFlightSubscriptions.remove(channelName);
    }
  }

  Future<void> _resubscribeAllRegisteredChannels() async {
    if (!_isInitialized || !_isConnected) return;
    if (!_usePureDartWs && _pusher == null) return;
    if (_usePureDartWs && _wsSocketId == null) return;

    for (final channelName in _listeners.keys.toList()) {
      if ((_listeners[channelName]?.isEmpty ?? true)) continue;
      await _ensureChannelSubscribedNatively(channelName);
    }
  }

  Future<void> init() {
    if (_isInitialized) return Future.value();
    if (_initFuture != null) return _initFuture!;

    _initFuture = _performInit().whenComplete(() {
      _initFuture = null;
    });
    return _initFuture!;
  }

  Future<void> _performInit() async {
    if (_isInitialized) return;

    try {
      await _fetchPusherConfig();

      final envKey = const String.fromEnvironment(
        'PUSHER_APP_KEY',
        defaultValue: '',
      );
      final envCluster = const String.fromEnvironment(
        'PUSHER_APP_CLUSTER',
        defaultValue: '',
      );
      final apiKey = (_serverKey != null && _serverKey!.isNotEmpty)
          ? _serverKey!
          : envKey;
      final cluster = (_serverCluster != null && _serverCluster!.isNotEmpty)
          ? _serverCluster!
          : envCluster;

      if (apiKey.isEmpty || cluster.isEmpty) {
        debugPrint(
          "Pusher: No valid apiKey or cluster provided. Scheduling retry.",
        );
        _isInitialized = false;
        _scheduleInitRetry();
        return;
      }

      _initRetryTimer?.cancel();
      _initRetryTimer = null;
      _initRetryAttempt = 0;
      _serverKey = apiKey;
      _serverCluster = cluster;

      if (_prefersPureDartWs) {
        _usePureDartWs = true;
        _isInitialized = true;
        debugPrint(
          "Pusher initialized with pure-Dart WebSocket transport (key: $apiKey, cluster: $cluster)",
        );
        return;
      }

      try {
        _pusher = PusherChannelsFlutter.getInstance();
        debugPrint(
          "Initializing native Pusher with key: $apiKey, cluster: $cluster",
        );

        await _pusher!.init(
          apiKey: apiKey,
          cluster: cluster,
          onConnectionStateChange: (currentState, previousState) {
            debugPrint(
              "Pusher Connection State Change: $previousState -> $currentState",
            );
            final normalizedState = currentState.toString().toUpperCase();
            final wasConnected = _isConnected;
            _isConnected = (normalizedState == 'CONNECTED');
            if (!_isConnected && normalizedState != 'CONNECTING') {
              _nativelySubscribedChannels.clear();
              _inFlightSubscriptions.clear();
            }
            if (!wasConnected && _isConnected) {
              if (_hasConnectedBefore) {
                if (!_reconnectController.isClosed) {
                  _reconnectController.add(null);
                }
              } else {
                _hasConnectedBefore = true;
              }
              unawaited(_resubscribeAllRegisteredChannels());
            }
          },
          onError: (message, code, exception) {
            debugPrint("Pusher Error: $message (code: $code) - $exception");
          },
          onEvent: (PusherEvent event) {
            debugPrint(
              "Pusher Event Received: ${event.channelName} - ${event.eventName}",
            );
            if (event.eventName.startsWith('pusher:') ||
                event.eventName.startsWith('pusher_internal:')) {
              return;
            }
            _decodeAndDispatchPayload(event.channelName, event.data);
          },
          onAuthorizer: (
            String channelName,
            String socketId,
            dynamic options,
          ) async {
            debugPrint(
              "Pusher Authorizing Channel: $channelName for socket: $socketId",
            );
            return await _authorizeChannel(channelName, socketId);
          },
        );
        _usePureDartWs = false;
        _isInitialized = true;
      } on MissingPluginException {
        debugPrint(
          "Pusher native plugin unavailable on this platform; falling back to pure-Dart WebSocket.",
        );
        _pusher = null;
        _usePureDartWs = true;
        _isInitialized = true;
      }
    } catch (e) {
      _isInitialized = false;
      debugPrint("Pusher Initialization Error: $e");
      _scheduleInitRetry();
    }
  }

  void _scheduleInitRetry() {
    if (_manuallyDisconnected || _listeners.isEmpty) return;
    _initRetryTimer?.cancel();
    _initRetryAttempt++;
    final delaySec = (3 * _initRetryAttempt).clamp(3, 20);
    _initRetryTimer = Timer(Duration(seconds: delaySec), () {
      if (!_manuallyDisconnected && !_isInitialized && _listeners.isNotEmpty) {
        unawaited(() async {
          await connect();
          if (_isInitialized && _isConnected) {
            await _resubscribeAllRegisteredChannels();
          }
        }());
      }
    });
  }

  void _scheduleChannelRetry(String channelName) {
    if (_manuallyDisconnected ||
        !_listeners.containsKey(channelName) ||
        (_listeners[channelName]?.isEmpty ?? true)) {
      return;
    }
    _channelRetryTimers.remove(channelName)?.cancel();
    final attempt = (_channelRetryAttempts[channelName] ?? 0) + 1;
    _channelRetryAttempts[channelName] = attempt;
    final delaySec = (2 * attempt).clamp(2, 15);
    _channelRetryTimers[channelName] = Timer(Duration(seconds: delaySec), () {
      _channelRetryTimers.remove(channelName);
      if (!_manuallyDisconnected &&
          _isConnected &&
          (_listeners[channelName]?.isNotEmpty ?? false) &&
          !_nativelySubscribedChannels.contains(channelName)) {
        unawaited(_ensureChannelSubscribedNatively(channelName));
      }
    });
  }

  Future<void> _connectPureDartWs() async {
    if (_wsTransport != null && _isConnected) return;
    if (_wsConnectFuture != null) {
      await _wsConnectFuture;
      return;
    }

    final key = _serverKey;
    final cluster = _serverCluster;
    if (key == null || key.isEmpty || cluster == null || cluster.isEmpty) {
      return;
    }

    _wsConnectFuture = () async {
      _wsReconnectTimer?.cancel();
      _wsReconnectTimer = null;

      await _teardownWsTransport();

      final wsUrl =
          'wss://ws-$cluster.pusher.com/app/$key?protocol=7&client=dart&version=1.0&flash=false';
      try {
        debugPrint("Pusher WS Connecting to $wsUrl");
        final transport = await connectPusherWebSocket(wsUrl);
        if (_manuallyDisconnected) {
          await transport.close();
          return;
        }
        _wsTransport = transport;
        _wsMsgSub = transport.messages.listen(_handleWsMessage);
        _wsCloseSub = transport.onClosed.listen((_) => _handleWsDisconnected());
      } catch (e) {
        debugPrint("Pusher WS Connect Error: $e");
        _handleWsDisconnected();
      }
    }().whenComplete(() {
      _wsConnectFuture = null;
    });

    await _wsConnectFuture;
  }

  void _handleWsMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return;
      final msg = Map<String, dynamic>.from(decoded);
      final eventName = msg['event']?.toString() ?? '';
      final channelName = msg['channel']?.toString();
      final data = msg['data'];

      if (eventName == 'pusher:connection_established') {
        Map<String, dynamic>? connData;
        if (data is Map) {
          connData = Map<String, dynamic>.from(data);
        } else if (data is String && data.isNotEmpty) {
          final parsed = jsonDecode(data);
          if (parsed is Map) {
            connData = Map<String, dynamic>.from(parsed);
          }
        }
        _wsSocketId = connData?['socket_id']?.toString();
        final rawTimeout = connData?['activity_timeout'];
        final activityTimeout = rawTimeout is num
            ? rawTimeout.toInt()
            : (int.tryParse(rawTimeout?.toString() ?? '') ?? 120);

        _isConnected = _wsSocketId != null && _wsSocketId!.isNotEmpty;
        _wsReconnectAttempt = 0;
        _nativelySubscribedChannels.clear();

        debugPrint(
          "Pusher WS Connected (socket_id: $_wsSocketId, activity_timeout: ${activityTimeout}s)",
        );

        _startWsPingTimer(activityTimeout);
        if (_isConnected) {
          if (_hasConnectedBefore) {
            if (!_reconnectController.isClosed) {
              _reconnectController.add(null);
            }
          } else {
            _hasConnectedBefore = true;
          }
          unawaited(_resubscribeAllRegisteredChannels());
        }
        return;
      }

      if (eventName == 'pusher:ping') {
        _wsTransport?.send(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        return;
      }

      if (eventName == 'pusher:pong') {
        return;
      }

      if (eventName == 'pusher:subscription_error') {
        debugPrint("Pusher WS Subscription Error for $channelName: $data");
        if (channelName != null) {
          _nativelySubscribedChannels.remove(channelName);
          _inFlightSubscriptions.remove(channelName);
          if (_listeners.containsKey(channelName) &&
              (_listeners[channelName]?.isNotEmpty ?? false)) {
            Future.delayed(const Duration(seconds: 2), () {
              if (!_manuallyDisconnected &&
                  _isConnected &&
                  _listeners.containsKey(channelName)) {
                unawaited(_ensureChannelSubscribedNatively(channelName));
              }
            });
          }
        }
        return;
      }

      if (eventName == 'pusher:error') {
        debugPrint("Pusher WS Error Frame: $data");
        if (channelName != null) {
          _nativelySubscribedChannels.remove(channelName);
          _inFlightSubscriptions.remove(channelName);
        }
        return;
      }

      if (eventName.startsWith('pusher:') ||
          eventName.startsWith('pusher_internal:')) {
        return;
      }

      debugPrint("Pusher WS Event Received: $channelName - $eventName");
      _decodeAndDispatchPayload(channelName, data);
    } catch (e) {
      debugPrint("Pusher WS Message Parse Error: $e");
    }
  }

  void _startWsPingTimer(int activityTimeoutSeconds) {
    _wsPingTimer?.cancel();
    final intervalSec = (activityTimeoutSeconds ~/ 2).clamp(15, 45);
    _wsPingTimer = Timer.periodic(Duration(seconds: intervalSec), (_) {
      if (_isConnected && _wsTransport != null) {
        _wsTransport?.send(jsonEncode({'event': 'pusher:ping', 'data': {}}));
      }
    });
  }

  Future<void> _teardownWsTransport() async {
    _wsPingTimer?.cancel();
    _wsPingTimer = null;
    await _wsMsgSub?.cancel();
    _wsMsgSub = null;
    await _wsCloseSub?.cancel();
    _wsCloseSub = null;
    final oldTransport = _wsTransport;
    _wsTransport = null;
    _wsSocketId = null;
    _isConnected = false;
    _nativelySubscribedChannels.clear();
    _inFlightSubscriptions.clear();
    if (oldTransport != null) {
      try {
        await oldTransport.close();
      } catch (_) {}
    }
  }

  void _handleWsDisconnected() {
    unawaited(_teardownWsTransport());
    if (_manuallyDisconnected || _listeners.isEmpty) return;

    _wsReconnectTimer?.cancel();
    _wsReconnectAttempt++;
    final delaySec = (2 * _wsReconnectAttempt).clamp(2, 15);
    debugPrint("Pusher WS scheduling reconnect in ${delaySec}s...");
    _wsReconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_manuallyDisconnected && _listeners.isNotEmpty) {
        unawaited(connect());
      }
    });
  }

  Future<void> connect() async {
    _manuallyDisconnected = false;
    if (!_isInitialized) {
      await init();
    }
    if (!_isInitialized) return;

    if (_usePureDartWs) {
      await _connectPureDartWs();
      return;
    }

    if (_isConnected) return;

    try {
      await _pusher?.connect();
    } catch (e) {
      debugPrint("Pusher Connect Error: $e");
    }
  }

  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _hasConnectedBefore = false;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _initRetryTimer?.cancel();
    _initRetryTimer = null;
    _initRetryAttempt = 0;
    for (final timer in _channelRetryTimers.values) {
      timer.cancel();
    }
    _channelRetryTimers.clear();
    _channelRetryAttempts.clear();
    try {
      await _teardownWsTransport();
      if (_isInitialized && !_usePureDartWs) {
        await _pusher?.disconnect();
      }
      _listeners.clear();
      _nativelySubscribedChannels.clear();
      _inFlightSubscriptions.clear();
      _isConnected = false;
      _usePureDartWs = false;
      _serverKey = null;
      _serverCluster = null;
      _isInitialized = false;
      _fetchFuture = null;
      _initFuture = null;
      _wsReconnectAttempt = 0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pusher_server_key');
      await prefs.remove('pusher_server_cluster');

      debugPrint("Pusher Disconnected and states cleared.");
    } catch (e) {
      debugPrint("Pusher Disconnect Error: $e");
    }
  }

  Future<void> subscribeToOrder(
    int orderId,
    void Function(Map<String, dynamic>) onUpdate,
  ) async {
    final channelName = 'private-sales-order.$orderId';
    await subscribeToChannel(channelName, onUpdate);
  }

  Future<void> unsubscribeFromOrder(
    int orderId, [
    void Function(Map<String, dynamic>)? onUpdate,
  ]) async {
    final channelName = 'private-sales-order.$orderId';
    await unsubscribeFromChannel(channelName, onUpdate);
  }

  Future<void> subscribeToChannel(
    String channelName,
    void Function(Map<String, dynamic>) onUpdate,
  ) async {
    _manuallyDisconnected = false;
    _listeners.putIfAbsent(channelName, () => []);
    if (!_listeners[channelName]!.contains(onUpdate)) {
      _listeners[channelName]!.add(onUpdate);
    }

    if (_isConnected &&
        (_nativelySubscribedChannels.contains(channelName) ||
            _inFlightSubscriptions.contains(channelName))) {
      debugPrint(
        "Pusher already subscribed to: $channelName. Registered callback, skipped duplicate subscribe.",
      );
      return;
    }

    try {
      await connect();
      if (!_isInitialized) {
        debugPrint(
          "Pusher not initialized, listener registered for $channelName.",
        );
        return;
      }
      await _ensureChannelSubscribedNatively(channelName);
    } catch (e) {
      debugPrint("Pusher Subscription Error: $e");
    }
  }

  Future<void> unsubscribeFromChannel(
    String channelName, [
    void Function(Map<String, dynamic>)? onUpdate,
  ]) async {
    if (onUpdate != null) {
      if (_listeners.containsKey(channelName)) {
        _listeners[channelName]!.remove(onUpdate);
        if (_listeners[channelName]!.isNotEmpty) {
          debugPrint(
            "Pusher kept channel subscription $channelName active for remaining (${_listeners[channelName]!.length}) listeners.",
          );
          return;
        }
      }
    } else {
      debugPrint(
        "Pusher WARNING: Unsubscribing channel $channelName without explicit callback reference.",
      );
    }
    _listeners.remove(channelName);
    _nativelySubscribedChannels.remove(channelName);
    _inFlightSubscriptions.remove(channelName);
    _channelRetryTimers.remove(channelName)?.cancel();
    _channelRetryAttempts.remove(channelName);

    if (!_isInitialized) return;

    if (_usePureDartWs) {
      if (_isConnected && _wsTransport != null) {
        _wsTransport?.send(
          jsonEncode({
            'event': 'pusher:unsubscribe',
            'data': {'channel': channelName},
          }),
        );
      }
      return;
    }

    try {
      await _pusher?.unsubscribe(channelName: channelName);
      debugPrint("Pusher Unsubscribed from: $channelName");
    } catch (e) {
      debugPrint("Pusher Unsubscribe Error: $e");
    }
  }
}
