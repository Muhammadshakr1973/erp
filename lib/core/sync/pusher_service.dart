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
  final Map<String, void Function(Map<String, dynamic>)> _listeners = {};
  
  String? _serverKey;
  String? _serverCluster;
  bool _isFetchingConfig = false;

  PusherService(this._ref);

  bool get isConnected => _isConnected;

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
      debugPrint("Pusher Config Fetch Error (will fallback to environment/default): $e");
    } finally {
      _isFetchingConfig = false;
    }
  }

  Future<void> init() async {
    if (_pusher != null) return;

    try {
      _pusher = PusherChannelsFlutter.getInstance();
      
      // Load the key/cluster dynamically from the backend for production safety
      await _fetchPusherConfig();
      
      final apiKey = _serverKey ?? const String.fromEnvironment('PUSHER_APP_KEY', defaultValue: 'gardi-pusher-key');
      final cluster = _serverCluster ?? const String.fromEnvironment('PUSHER_APP_CLUSTER', defaultValue: 'mt1');

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
          final payloadStr = event.data;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final Map<String, dynamic> payload = Map<String, dynamic>.from(jsonDecode(payloadStr));
              final listener = _listeners[event.channelName];
              if (listener != null) {
                listener(payload);
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
    } catch (e) {
      debugPrint("Pusher Initialization Error: $e");
    }
  }

  Future<void> connect() async {
    await init();
    try {
      await _pusher?.connect();
    } catch (e) {
      debugPrint("Pusher Connect Error: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await _pusher?.disconnect();
      _listeners.clear();
      _isConnected = false;
      _serverKey = null;
      _serverCluster = null;
      debugPrint("Pusher Disconnected and states cleared.");
    } catch (e) {
      debugPrint("Pusher Disconnect Error: $e");
    }
  }

  Future<void> subscribeToOrder(int orderId, void Function(Map<String, dynamic>) onUpdate) async {
    final channelName = 'private-sales-order.$orderId';
    
    // Check if subscription listener is already present to prevent duplicate listeners
    final alreadySubscribed = _listeners.containsKey(channelName);
    _listeners[channelName] = onUpdate;

    if (alreadySubscribed) {
      debugPrint("Pusher already subscribed to: $channelName. Updated local listener callback, skipped duplicate native subscribe.");
      return;
    }

    try {
      await connect();
      await _pusher?.subscribe(channelName: channelName);
      debugPrint("Pusher Subscribed to: $channelName");
    } catch (e) {
      debugPrint("Pusher Subscription Error: $e");
    }
  }

  Future<void> unsubscribeFromOrder(int orderId) async {
    final channelName = 'private-sales-order.$orderId';
    _listeners.remove(channelName);

    try {
      await _pusher?.unsubscribe(channelName: channelName);
      debugPrint("Pusher Unsubscribed from: $channelName");
    } catch (e) {
      debugPrint("Pusher Unsubscribe Error: $e");
    }
  }
}
