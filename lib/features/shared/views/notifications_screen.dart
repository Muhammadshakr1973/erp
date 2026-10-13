import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/notification_sound_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // ئاگادارکردنەوەکان لە کاتی کردنەوەدا ڕاستەوخۆ ناکرێن بە خوێندراوە بۆ ئەوەی بەکارهێنەر بتوانێت ئاگادارکردنەوە نوێیەکان بە ڕەنگی تۆختر ببینێت
  }

  void _markAllAsReadSilently() {
    final unread = ref.read(unreadNotificationsCountProvider);
    if (unread > 0) {
      ref.read(notificationsListProvider.notifier).markAllAsRead();
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read immediately
    if (!notification.isRead) {
      ref.read(notificationsListProvider.notifier).markAsRead(notification.id);
    }

    // Handle navigation based on payload
    final data = notification.data;
    if (data != null) {
      if (data['order_id'] != null) {
        context.push('/order/${data['order_id']}');
      } else if (data['customer_id'] != null) {
        context.push('/customer/${data['customer_id']}');
      } else if (data['trip_id'] != null) {
        context.push('/trip/${data['trip_id']}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final selectedFilter = ref.watch(notificationFilterTypeProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _markAllAsReadSilently();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ئاگادارکردنەوەکان', style: AppTextStyles.h2),
          actions: [
            IconButton(
              icon: Icon(
                ref.watch(notificationSoundEnabledProvider)
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
              tooltip: ref.watch(notificationSoundEnabledProvider)
                  ? 'دەنگی ئاگادارکردنەوەکان چالاکە'
                  : 'دەنگی ئاگادارکردنەوەکان ناچالاکە',
              onPressed: () {
                final current = ref.read(notificationSoundEnabledProvider);
                final notifier = ref.read(notificationSoundEnabledProvider.notifier);
                notifier.toggleSound(!current);
                if (!current) {
                  NotificationSoundService.playNotificationSound(soundEnabled: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('دەنگی ئاگادارکردنەوەکان چالاککرا'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('دەنگی ئاگادارکردنەوەکان ناچالاککرا'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: () {
                  ref.read(notificationsListProvider.notifier).markAllAsRead();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('هەموو ئاگادارکردنەوەکان خوێندرانەوە'),
                    ),
                  );
                },
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('هەمووی بخوێنەوە'),
              ),
          ],
        ),
        body: _buildInAppNotificationsTab(
          context,
          notificationsAsync,
          selectedFilter,
        ),
      ),
    );
  }

  Widget _buildInAppNotificationsTab(
    BuildContext context,
    AsyncValue<List<AppNotification>> notificationsAsync,
    String? selectedFilter,
  ) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    return Column(
      children: [
        // Filter Chips Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: theme.colorScheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('هەموو', null, selectedFilter),
                const SizedBox(width: 8),
                _buildFilterChip('پسوڵەکان', 'order', selectedFilter),
                if (user?.role.toLowerCase() != 'warehouse') ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('پارەدان', 'payment', selectedFilter),
                ],
                const SizedBox(width: 8),
                _buildFilterChip('کۆگا و ستۆک', 'stock', selectedFilter),
                if (user?.role.toLowerCase() != 'warehouse') ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('کۆمسیۆن', 'commission', selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('کڕیارەکان', 'customer', selectedFilter),
                ],
                const SizedBox(width: 8),
                _buildFilterChip('سیستەم', 'system', selectedFilter),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Notifications List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(notificationsListProvider.notifier)
                  .loadNotifications();
            },
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(notificationsListProvider.notifier)
                            .loadNotifications(),
                        child: const Text('دووبارە هەوڵ بدەرەوە'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'هیچ ئاگادارکردنەوەیەک نییە',
                            style: AppTextStyles.h3.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'کاتێک پەیام یان ڕووداوێکی نوێ ڕووبدات لێرە دەردەکەوێت.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(context, notification);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? type, String? currentFilter) {
    final isSelected = currentFilter == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        ref.read(notificationFilterTypeProvider.notifier).state = type;
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notification,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final adaptiveColor = notification.iconColorAdaptive(context);
    final isUnread = !notification.isRead;

    // جیاکردنەوەی نۆتیفیکەیشنی نوێ/نەبینراو:
    // ئەوانەی بۆ جاری یەکەمە دەبینرێن ڕەنگیان تۆخترە بە چوارچێوەی دیار، و ئەوانی تر ناتۆخترن
    final Color cardBgColor = isUnread
        ? (isDark
            ? const Color(0xFF162544) // ڕەنگی تۆخی دیار لە دۆخی تاریک
            : const Color(0xFFE2EAF8)) // ڕەنگی تۆخی دیار لە دۆخی ڕووناک
        : (isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.35) // ناتۆختر و کەمڕەنگتر
            : Colors.white.withValues(alpha: 0.7)); // ناتۆختر و کاڵ

    final Color cardBorderColor = isUnread
        ? (isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.65)
            : theme.colorScheme.primary.withValues(alpha: 0.45))
        : (isDark
            ? theme.colorScheme.outline.withValues(alpha: 0.12)
            : AppColors.borderLight.withValues(alpha: 0.5));

    return AppCard(
      onTap: () => _handleNotificationTap(notification),
      color: cardBgColor,
      borderColor: cardBorderColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: adaptiveColor.withValues(alpha: isUnread ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: isUnread
                  ? Border.all(
                      color: adaptiveColor.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              notification.iconData,
              color: isUnread
                  ? adaptiveColor
                  : adaptiveColor.withValues(alpha: 0.45),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: isUnread
                              ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.infoDark
                                    : theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'نوێ',
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.infoDark
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isUnread
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.95)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      notification.timeAgoKurdish,
                      style: AppTextStyles.caption.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: isUnread ? 0.65 : 0.4,
                        ),
                      ),
                    ),
                    Text(
                      notification.typeLabelKurdish,
                      style: AppTextStyles.caption.copyWith(
                        color: isUnread
                            ? adaptiveColor
                            : adaptiveColor.withValues(alpha: 0.55),
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

