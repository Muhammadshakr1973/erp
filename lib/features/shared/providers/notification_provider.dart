import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/pusher_service.dart';
import '../../../core/utils/notification_sound_service.dart';
import '../../admin/views/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/providers/driver_providers.dart';
import '../../orders/providers/orders_provider.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../../warehouse/providers/warehouse_provider.dart';
import '../models/notification_model.dart';
import 'customer_provider.dart';

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
  final PusherService _pusherService;
  final String? _userRole;
  String? _subscribedChannelName;
  Timer? _pollingTimer;
  bool _isPollingActive = false;

  NotificationsNotifier(this._api, this._ref, this._filterType)
    : _pusherService = _ref.read(pusherServiceProvider),
      _userRole = _ref.read(authProvider).user?.role,
      super(const AsyncValue.loading()) {
    final user = _ref.read(authProvider).user;
    if (user != null) {
      loadNotifications();
      _subscribeToLiveNotifications();
      _startAutoPolling();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  void _subscribeToLiveNotifications() {
    final user = _ref.read(authProvider).user;
    if (user != null) {
      final channelName = 'private-user-notifications.${user.id}';
      _subscribedChannelName = channelName;
      _pusherService.subscribeToChannel(channelName, _onLiveNotificationReceived);
    }
  }

  void _startAutoPolling() {
    _pollingTimer?.cancel();
    // High-frequency background polling every 8 seconds guarantees instant updates
    // on Web, Mobile, and when Websockets reconnect or drop.
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollForNewNotifications();
    });
  }

  Future<void> _pollForNewNotifications() async {
    if (_isPollingActive || !mounted) return;
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    _isPollingActive = true;
    try {
      final queryParams = <String, dynamic>{'per_page': 20};
      final filterType = _filterType;
      if (filterType != null && filterType.isNotEmpty) {
        queryParams['type'] = filterType;
      }

      final response = await _api.client.get(
        ApiConstants.notifications,
        queryParameters: queryParams,
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is Map) {
        final resData = response.data as Map<String, dynamic>;
        if (resData['data'] is List) {
          final List list = resData['data'] as List;
          var fetchedItems = list
              .map((json) => AppNotification.fromJson(Map<String, dynamic>.from(json)))
              .toList();

          // Role restriction filter for warehouse
          final userRole = _userRole;
          if (userRole != null && userRole.toLowerCase() == 'warehouse') {
            fetchedItems = fetchedItems.where((n) {
              final type = n.type.toLowerCase();
              return type != 'customer' && type != 'commission' && type != 'payment';
            }).toList();
          }

          final currentList = state.value ?? [];
          final currentIds = currentList.map((n) => n.id).toSet();

          // Identify newly arrived notifications that are not yet in state
          final newNotifications = fetchedItems.where((n) => !currentIds.contains(n.id)).toList();

          if (newNotifications.isNotEmpty) {
            // Play notification sound if new items arrived
            final soundEnabled = _ref.read(notificationSoundEnabledProvider);
            NotificationSoundService.playNotificationSound(soundEnabled: soundEnabled);

            // Display top notification toast overlay for incoming notifications
            for (final n in newNotifications) {
              AppSnackbar.info(null, n.body, title: n.title);
            }

            final updatedList = [...newNotifications, ...currentList];
            state = AsyncValue.data(updatedList);

            // Invalidate screen providers so active views refresh immediately
            for (final n in newNotifications) {
              _invalidateProvidersForNotificationType(n.type);
            }
          }

          // Update unread count
          final unreadCount = resData['unread_count'] as int? ??
              fetchedItems.where((n) => !n.isRead).length;
          _ref.read(unreadNotificationsCountProvider.notifier).state = unreadCount;
        }
      }
    } catch (_) {
      // Ignore background network errors gracefully
    } finally {
      _isPollingActive = false;
    }
  }

  void _invalidateProvidersForNotificationType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'order') {
      _ref.invalidate(ordersToPackProvider);
      _ref.invalidate(ordersListProvider);
      _ref.invalidate(warehouseDashboardProvider);
      _ref.invalidate(readyOrdersForDeliveryProvider);
      _ref.invalidate(salesmanDashboardProvider);
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(driverTripsProvider);
    } else if (lowerType == 'payment') {
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(salesmanDashboardProvider);
    } else if (lowerType == 'customer') {
      _ref.invalidate(customerListProvider);
    } else if (lowerType == 'stock') {
      _ref.invalidate(warehouseStocksProvider);
      _ref.invalidate(warehouseDashboardProvider);
    }
  }

  void _onLiveNotificationReceived(Map<String, dynamic> data) {
    try {
      Map<String, dynamic>? notificationJson;
      if (data.containsKey('notification') && data['notification'] is Map) {
        notificationJson = Map<String, dynamic>.from(data['notification']);
      } else if (data.containsKey('id') && data.containsKey('title')) {
        notificationJson = data;
      }

      if (notificationJson == null) return;

      final newNotification = AppNotification.fromJson(notificationJson);

      // Filter out unauthorized notifications for warehouse role
      final userRole = _userRole;
      if (userRole != null && userRole.toLowerCase() == 'warehouse') {
        final type = newNotification.type.toLowerCase();
        if (type == 'customer' || type == 'commission' || type == 'payment') {
          return;
        }
      }

      final currentList = state.value ?? [];
      if (currentList.any((n) => n.id == newNotification.id)) return;

      // Play notification sound & vibration feedback
      final soundEnabled = _ref.read(notificationSoundEnabledProvider);
      NotificationSoundService.playNotificationSound(soundEnabled: soundEnabled);

      // Display top notification toast overlay
      AppSnackbar.info(null, newNotification.body, title: newNotification.title);

      final List<AppNotification> updatedList;
      final filterType = _filterType;
      if (filterType == null || filterType.isEmpty || newNotification.type.toLowerCase() == filterType.toLowerCase()) {
        updatedList = [newNotification, ...currentList];
      } else {
        updatedList = currentList;
      }

      state = AsyncValue.data(updatedList);

      if (data.containsKey('unread_count') && data['unread_count'] is int) {
        _ref.read(unreadNotificationsCountProvider.notifier).state = data['unread_count'] as int;
      } else {
        final count = _ref.read(unreadNotificationsCountProvider);
        _ref.read(unreadNotificationsCountProvider.notifier).state = count + 1;
      }

      // Automatically refresh dependent modules
      _invalidateProvidersForNotificationType(newNotification.type);
    } catch (e) {
      debugPrint("Error parsing live notification: $e");
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    final channelName = _subscribedChannelName;
    if (channelName != null) {
      _pusherService.unsubscribeFromChannel(channelName, _onLiveNotificationReceived);
    }
    super.dispose();
  }

  Future<void> loadNotifications() async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'per_page': 50};
      final filterType = _filterType;
      if (filterType != null && filterType.isNotEmpty) {
        queryParams['type'] = filterType;
      }

      final response = await _api.client.get(
        ApiConstants.notifications,
        queryParameters: queryParams,
      );

      if (!mounted) return;

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
        final userRole = _userRole;
        if (userRole != null && userRole.toLowerCase() == 'warehouse') {
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
      if (!mounted) return;
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
