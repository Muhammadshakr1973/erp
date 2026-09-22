import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../api_client.dart';

final pusherServiceProvider = Provider<PusherService>((ref) {
  return PusherService(ref);
});

class PusherService {
  final Ref _ref;
  PusherChannelsFlutter? _pusher;
  bool _isConnected = false;
  bool _isInitialized = false;
  final Map<String, List<void Function(Map<String, dynamic>)>> _listeners = {};
  
  String? _serverKey;
  String? _serverCluster;
  bool _isFetchingConfig = false;

  PusherService(this._ref);

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  Future<void> _fetchPusherConfig() async {
    if (_serverKey != null && _serverCluster != null) return;
    if (_isFetchingConfig) return;
    _isFetchingConfig = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
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
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        _serverKey = response.data['key']?.toString();
        _serverCluster = response.data['cluster']?.toString();
        debugPrint("Pusher Config dynamically loaded: key=$_serverKey, cluster=$_serverCluster");
      }
    } catch (e) {
      debugPrint("Pusher Config Fetch Error: $e");
    } finally {
      _isFetchingConfig = false;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Load the key/cluster dynamically from the backend for production safety
      await _fetchPusherConfig();
      
      final apiKey = _serverKey ?? const String.fromEnvironment('PUSHER_APP_KEY', defaultValue: '');
      final cluster = _serverCluster ?? const String.fromEnvironment('PUSHER_APP_CLUSTER', defaultValue: '');

      if (apiKey.isEmpty || cluster.isEmpty) {
        debugPrint("Pusher: No valid apiKey or cluster provided. Realtime pusher events safely disabled.");
        _isInitialized = false;
        return;
      }

      _pusher = PusherChannelsFlutter.getInstance();
      debugPrint("Initializing Pusher with key: $apiKey, cluster: $cluster");

      await _pusher!.init(
        apiKey: apiKey,
        cluster: cluster,
        onConnectionStateChange: (currentState, previousState) {
          debugPrint("Pusher Connection State Change: $previousState -> $currentState");
          _isConnected = (currentState == 'CONNECTED');
        },
        onError: (message, code, exception) {
          debugPrint("Pusher Error: $message (code: $code) - $exception");
        },
        onEvent: (PusherEvent event) {
          debugPrint("Pusher Event Received: ${event.channelName} - ${event.eventName}");
          
          // Ignore Pusher internal/protocol events (e.g. pusher:subscription_succeeded)
          // to prevent infinite invalidation loops in providers.
          if (event.eventName.startsWith('pusher:')) {
            debugPrint("Pusher: Ignoring internal protocol event: ${event.eventName}");
            return;
          }

          final dynamic rawData = event.data;
          if (rawData != null) {
            try {
              Map<String, dynamic>? payload;
              if (rawData is Map) {
                payload = Map<String, dynamic>.from(rawData);
              } else if (rawData is String) {
                if (rawData.isNotEmpty) {
                  payload = Map<String, dynamic>.from(jsonDecode(rawData));
                }
              }
              
              if (payload != null) {
                final listeners = _listeners[event.channelName];
                if (listeners != null && listeners.isNotEmpty) {
                  for (final listener in List.of(listeners)) {
                    try {
                      listener(payload);
                    } catch (e) {
                      debugPrint("Pusher Error in listener callback: $e");
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint("Pusher Error decoding payload: $e");
            }
          }
        },
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          debugPrint("Pusher Authorizing Channel: $channelName for socket: $socketId");
          try {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('auth_token');
            if (token == null) {
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
            return response.data;
          } catch (e) {
            debugPrint("Pusher Authorizer Request Error: $e");
            return {'error': e.toString()};
          }
        },
      );
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint("Pusher Initialization Error: $e");
    }
  }

  Future<void> connect() async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isInitialized) return;

    try {
      await _pusher?.connect();
    } catch (e) {
      debugPrint("Pusher Connect Error: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (_isInitialized) {
        await _pusher?.disconnect();
      }
      _listeners.clear();
      _isConnected = false;
      _serverKey = null;
      _serverCluster = null;
      _isInitialized = false;
      debugPrint("Pusher Disconnected and states cleared.");
    } catch (e) {
      debugPrint("Pusher Disconnect Error: $e");
    }
  }

  Future<void> subscribeToOrder(int orderId, void Function(Map<String, dynamic>) onUpdate) async {
    final channelName = 'private-sales-order.$orderId';
    await subscribeToChannel(channelName, onUpdate);
  }

  Future<void> unsubscribeFromOrder(int orderId, [void Function(Map<String, dynamic>)? onUpdate]) async {
    final channelName = 'private-sales-order.$orderId';
    await unsubscribeFromChannel(channelName, onUpdate);
  }

  Future<void> subscribeToChannel(String channelName, void Function(Map<String, dynamic>) onUpdate) async {
    _listeners.putIfAbsent(channelName, () => []);
    if (!_listeners[channelName]!.contains(onUpdate)) {
      _listeners[channelName]!.add(onUpdate);
    }

    final alreadySubscribed = _listeners[channelName]!.length > 1;
    if (alreadySubscribed) {
      debugPrint("Pusher already subscribed to: $channelName. Registered callback, skipped duplicate native subscribe.");
      return;
    }

    try {
      await connect();
      if (!_isInitialized) {
        debugPrint("Pusher not initialized, skipping native subscribe to $channelName (listener registered)");
        return;
      }
      await _pusher?.subscribe(channelName: channelName);
      debugPrint("Pusher Subscribed to: $channelName");
    } catch (e) {
      debugPrint("Pusher Subscription Error: $e");
    }
  }

  Future<void> unsubscribeFromChannel(String channelName, [void Function(Map<String, dynamic>)? onUpdate]) async {
    if (onUpdate != null && _listeners.containsKey(channelName)) {
      _listeners[channelName]!.remove(onUpdate);
      if (_listeners[channelName]!.isNotEmpty) {
        debugPrint("Pusher kept channel subscription $channelName active for remaining listeners.");
        return;
      }
    }
    _listeners.remove(channelName);

    if (!_isInitialized) return;

    try {
      await _pusher?.unsubscribe(channelName: channelName);
      debugPrint("Pusher Unsubscribed from: $channelName");
    } catch (e) {
      debugPrint("Pusher Unsubscribe Error: $e");
    }
  }
}
