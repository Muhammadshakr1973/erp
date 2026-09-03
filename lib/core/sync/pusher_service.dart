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

  PusherService(this._ref);

  bool get isConnected => _isConnected;

  Future<void> init() async {
    if (_pusher != null) return;

    try {
      _pusher = PusherChannelsFlutter.getInstance();
      
      const apiKey = String.fromEnvironment('PUSHER_APP_KEY', defaultValue: 'gardi-pusher-key');
      const cluster = String.fromEnvironment('PUSHER_APP_CLUSTER', defaultValue: 'mt1');

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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

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
    } catch (e) {
      debugPrint("Pusher Disconnect Error: $e");
    }
  }

  Future<void> subscribeToOrder(int orderId, void Function(Map<String, dynamic>) onUpdate) async {
    final channelName = 'private-sales-order.$orderId';
    _listeners[channelName] = onUpdate;

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
