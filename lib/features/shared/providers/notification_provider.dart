import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../models/notification_model.dart';

// Unread count provider for badges across the app
final unreadNotificationsCountProvider = StateProvider<int>((ref) => 0);

// Selected filter type for notifications (null for all)
final notificationFilterTypeProvider = StateProvider<String?>((ref) => null);

// Notifications list provider
final notificationsListProvider =
    StateNotifierProvider<
      NotificationsNotifier,
      AsyncValue<List<AppNotification>>
    >((ref) {
      final api = ref.watch(apiClientProvider);
      final filterType = ref.watch(notificationFilterTypeProvider);
      return NotificationsNotifier(api, ref, filterType);
    });

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final ApiClient _api;
  final Ref _ref;
  final String? _filterType;

  NotificationsNotifier(this._api, this._ref, this._filterType)
    : super(const AsyncValue.loading()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'per_page': 50};
      if (_filterType != null && _filterType!.isNotEmpty) {
        queryParams['type'] = _filterType;
      }

      final response = await _api.client.get(
        ApiConstants.notifications,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List list = response.data['data'] ?? [];
        final items = list
            .map((json) => AppNotification.fromJson(json))
            .toList();

        final unreadCount =
            response.data['unread_count'] as int? ??
            items.where((n) => !n.isRead).length;
        _ref.read(unreadNotificationsCountProvider.notifier).state =
            unreadCount;

        state = AsyncValue.data(items);
      } else {
        state = AsyncValue.error(
          'هەڵەی وەرگرتنی ئاگادارکردنەوەکان',
          StackTrace.current,
        );
      }
    } catch (e, stack) {
      state = AsyncValue.error(_api.parseError(e), stack);
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final currentData = state.value;
    if (currentData == null) return;

    // Optimistically update local state
    state = AsyncValue.data(
      currentData.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList(),
    );

    // Update unread count
    final count = _ref.read(unreadNotificationsCountProvider);
    if (count > 0) {
      _ref.read(unreadNotificationsCountProvider.notifier).state = count - 1;
    }

    try {
      await _api.client.post(
        '${ApiConstants.notifications}/$notificationId/read',
      );
    } catch (e) {
      // Revert if failed
      loadNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    final currentData = state.value;
    if (currentData == null) return;

    // Optimistically mark all as read
    state = AsyncValue.data(
      currentData
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList(),
    );
    _ref.read(unreadNotificationsCountProvider.notifier).state = 0;

    try {
      await _api.client.post(ApiConstants.notificationsMarkAllRead);
    } catch (e) {
      loadNotifications();
    }
  }
}

// WhatsApp Logs Provider (BR-R04)
final whatsAppLogsProvider =
    FutureProvider.family<List<WhatsAppLog>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          ApiConstants.whatsAppLogs,
          queryParameters: filters,
        );

        if (response.statusCode == 200) {
          final List list = response.data['data'] ?? [];
          return list.map((json) => WhatsAppLog.fromJson(json)).toList();
        }
        throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}');
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

// General notification actions
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationActions(api, ref);
});

class NotificationActions {
  final ApiClient _api;
  final Ref _ref;

  NotificationActions(this._api, this._ref);

  Future<void> refreshUnreadCount() async {
    try {
      final res = await _api.client.get(ApiConstants.notificationsUnreadCount);
      if (res.statusCode == 200) {
        final count = res.data['unread_count'] as int? ?? 0;
        _ref.read(unreadNotificationsCountProvider.notifier).state = count;
      }
    } catch (_) {}
  }

  Future<void> registerDeviceToken(
    String token, {
    String deviceType = 'android',
    String? deviceName,
  }) async {
    try {
      await _api.client.post(
        ApiConstants.deviceToken,
        data: {
          'token': token,
          'device_token': token,
          'device_type': deviceType,
          'device_name': deviceName,
        },
      );
    } catch (_) {}
  }

  Future<void> removeDeviceToken(String token) async {
    try {
      await _api.client.delete(
        ApiConstants.deviceToken,
        data: {'token': token, 'device_token': token},
      );
    } catch (_) {}
  }

  Future<WhatsAppLog> retryWhatsApp(int logId) async {
    try {
      final res = await _api.client.post(
        '${ApiConstants.notifications}/whatsapp/$logId/retry',
      );
      return WhatsAppLog.fromJson(res.data['data']);
    } catch (e) {
      throw Exception(_api.parseError(e));
    }
  }
}
