import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
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
      // Watch authProvider to trigger rebuilding the notifier on login/logout
      ref.watch(authProvider);
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
    _subscribeToLiveNotifications();
  }

  void _subscribeToLiveNotifications() {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      final channelName = 'private-user-notifications.${user.id}';
      _ref.read(pusherServiceProvider).subscribeToChannel(channelName, _onLiveNotificationReceived);
    }
  }

  void _onLiveNotificationReceived(Map<String, dynamic> data) {
    if (data.containsKey('notification')) {
      try {
        final notificationJson = data['notification'];
        final newNotification = AppNotification.fromJson(Map<String, dynamic>.from(notificationJson));
        
        // Filter out unauthorized notifications for warehouse role
        final user = _ref.read(authProvider).user;
        if (user != null && user.role.toLowerCase() == 'warehouse') {
          final type = newNotification.type.toLowerCase();
          if (type == 'customer' || type == 'commission' || type == 'payment') {
            return;
          }
        }

        final currentList = state.value ?? [];
        if (currentList.any((n) => n.id == newNotification.id)) return;

        final List<AppNotification> updatedList;
        if (_filterType == null || _filterType!.isEmpty || newNotification.type.toLowerCase() == _filterType!.toLowerCase()) {
          updatedList = [newNotification, ...currentList];
        } else {
          updatedList = currentList;
        }

        state = AsyncValue.data(updatedList);

        if (data.containsKey('unread_count')) {
          _ref.read(unreadNotificationsCountProvider.notifier).state = data['unread_count'] as int;
        } else {
          final count = _ref.read(unreadNotificationsCountProvider);
          _ref.read(unreadNotificationsCountProvider.notifier).state = count + 1;
        }
      } catch (e) {
        debugPrint("Error parsing live notification: $e");
      }
    }
  }

  @override
  void dispose() {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      final channelName = 'private-user-notifications.${user.id}';
      _ref.read(pusherServiceProvider).unsubscribeFromChannel(channelName, _onLiveNotificationReceived);
    }
    super.dispose();
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
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed notifications response payload)',
          );
        }
        final List list = resData['data'] as List;
        var items = list
            .map((json) => AppNotification.fromJson(json))
            .toList();

        // Client-side safety filter for warehouse role
        final user = _ref.read(authProvider).user;
        if (user != null && user.role.toLowerCase() == 'warehouse') {
          items = items.where((n) {
            final type = n.type.toLowerCase();
            return type != 'customer' && type != 'commission' && type != 'payment';
          }).toList();
        }

        final unreadCount =
            resData['unread_count'] as int? ??
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
          final resData = response.data;
          if (resData is! Map || resData['data'] is! List) {
            throw FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed WhatsApp logs response payload)',
            );
          }
          final List list = resData['data'] as List;
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
        final resData = res.data;
        if (resData is Map && resData.containsKey('unread_count')) {
          final count = resData['unread_count'] as int;
          _ref.read(unreadNotificationsCountProvider.notifier).state = count;
        }
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
      final resData = res.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed WhatsApp retry log payload)',
        );
      }
      return WhatsAppLog.fromJson(Map<String, dynamic>.from(resData['data']));
    } catch (e) {
      throw Exception(_api.parseError(e));
    }
  }
}
