import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/system_settings_model.dart';

final systemSettingsProvider = StateNotifierProvider<SystemSettingsNotifier,
    AsyncValue<SystemSettingsModel>>((ref) {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);
  final user = ref.watch(authProvider).user;
  final isOwner = user?.isOwner ?? false;
  return SystemSettingsNotifier(api, pusher, isOwner);
});

class SystemSettingsNotifier
    extends StateNotifier<AsyncValue<SystemSettingsModel>> {
  final ApiClient _api;
  final PusherService _pusher;
  final bool _isOwner;
  StreamSubscription<void>? _reconnectSub;

  SystemSettingsNotifier(this._api, this._pusher, this._isOwner)
      : super(const AsyncValue.loading()) {
    if (_isOwner) {
      fetchSettings();
      _pusher.subscribeToChannel('private-settings', _onSettingsEvent);
      _reconnectSub = _pusher.onReconnected.listen((_) {
        unawaited(fetchSettings());
      });
    } else {
      state = AsyncValue.error(
        'تەنها خاوەنکار (Owner) مۆڵەتی گەیشتنی بەم بەشە هەیە.',
        StackTrace.current,
      );
    }
  }

  void _onSettingsEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received on private-settings: $eventData");
    unawaited(fetchSettings());
  }

  @override
  void dispose() {
    _reconnectSub?.cancel();
    if (_isOwner) {
      _pusher.unsubscribeFromChannel('private-settings', _onSettingsEvent);
    }
    super.dispose();
  }

  Future<void> fetchSettings() async {
    if (!_isOwner) return;
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final response = await _api.client.get(ApiConstants.settings);
      if (!mounted) return;
      if (response.statusCode == 200 && response.data is Map) {
        final rawData = response.data['data'];
        if (rawData is Map) {
          state = AsyncValue.data(
            SystemSettingsModel.fromJson(Map<String, dynamic>.from(rawData)),
          );
          return;
        }
      }
      throw Exception(
        _api.extractErrorMessage(
          response.data,
          defaultMsg: 'هەڵەیەک لە هێنانی ڕێکخستنەکاندا ڕوویدا',
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      if (!state.hasValue) {
        state = AsyncValue.error(_api.parseError(e), st);
      }
    }
  }

  Future<String?> saveSettings(Map<String, dynamic> payload) async {
    if (!_isOwner) {
      return 'تەنها خاوەنکار (Owner) دەتوانێت ڕێکخستنەکان پاشەکەوت بکات.';
    }
    try {
      final response = await _api.client.put(
        ApiConstants.settings,
        data: payload,
      );
      if (!mounted) return null;
      if (response.statusCode == 200 && response.data is Map) {
        final rawData = response.data['data'];
        if (rawData is Map) {
          // Smart in-place state update without full screen reload
          state = AsyncValue.data(
            SystemSettingsModel.fromJson(Map<String, dynamic>.from(rawData)),
          );
        }
        return null;
      }
      return _api.extractErrorMessage(
        response.data,
        defaultMsg: 'پاشەکەوتکردنی ڕێکخستنەکان سەرکەوتوو نەبوو',
      );
    } catch (e) {
      return _api.parseError(e);
    }
  }

  Future<String?> clearServerCache() async {
    if (!_isOwner) {
      return 'تەنها خاوەنکار (Owner) مۆڵەتی ئەم کردارەی هەیە.';
    }
    try {
      final response = await _api.client.post(ApiConstants.settingsClearCache);
      if (!mounted) return null;
      if (response.statusCode == 200 && response.data is Map) {
        final rawData = response.data['data'];
        if (rawData is Map) {
          state = AsyncValue.data(
            SystemSettingsModel.fromJson(Map<String, dynamic>.from(rawData)),
          );
        }
        return null;
      }
      return _api.extractErrorMessage(
        response.data,
        defaultMsg: 'پاککردنەوەی کاش سەرکەوتوو نەبوو',
      );
    } catch (e) {
      return _api.parseError(e);
    }
  }
}
