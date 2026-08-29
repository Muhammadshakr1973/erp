import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedWhatsAppStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final isPrivileged =
        user != null &&
        (user.role.toLowerCase() == 'admin' ||
            user.role.toLowerCase() == 'owner');

    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final selectedFilter = ref.watch(notificationFilterTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ئاگادارکردنەوەکان', style: AppTextStyles.h2),
        bottom: isPrivileged
            ? TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelStyle: AppTextStyles.bodyBold,
                unselectedLabelStyle: AppTextStyles.bodyMedium,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('سیستەم'),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'مێژووی وەتسئاپ'),
                ],
              )
            : null,
        actions: [
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
      body: isPrivileged
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildInAppNotificationsTab(
                  context,
                  notificationsAsync,
                  selectedFilter,
                ),
                _buildWhatsAppLogsTab(context),
              ],
            )
          : _buildInAppNotificationsTab(
              context,
              notificationsAsync,
              selectedFilter,
            ),
    );
  }

  Widget _buildInAppNotificationsTab(
    BuildContext context,
    AsyncValue<List<AppNotification>> notificationsAsync,
    String? selectedFilter,
  ) {
    final theme = Theme.of(context);

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
                const SizedBox(width: 8),
                _buildFilterChip('پارەدان', 'payment', selectedFilter),
                const SizedBox(width: 8),
                _buildFilterChip('کۆگا و ستۆک', 'stock', selectedFilter),
                const SizedBox(width: 8),
                _buildFilterChip('کۆمسیۆن', 'commission', selectedFilter),
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

    return AppCard(
      onTap: () => _handleNotificationTap(notification),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: notification.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              notification.iconData,
              color: notification.iconColor,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: notification.isRead
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurface,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: notification.isRead ? 0.65 : 0.88,
                    ),
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
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      notification.typeLabelKurdish,
                      style: AppTextStyles.caption.copyWith(
                        color: notification.iconColor,
                        fontWeight: FontWeight.w600,
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

  Widget _buildWhatsAppLogsTab(BuildContext context) {
    final filters = <String, dynamic>{};
    if (_selectedWhatsAppStatus != null) {
      filters['status'] = _selectedWhatsAppStatus;
    }

    final logsAsync = ref.watch(whatsAppLogsProvider(filters));
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filter bar for WhatsApp status
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
                FilterChip(
                  selected: _selectedWhatsAppStatus == null,
                  label: const Text('هەموو'),
                  onSelected: (_) =>
                      setState(() => _selectedWhatsAppStatus = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _selectedWhatsAppStatus == 'SENT',
                  label: const Text('نێردراو'),
                  onSelected: (_) =>
                      setState(() => _selectedWhatsAppStatus = 'SENT'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _selectedWhatsAppStatus == 'SIMULATED',
                  label: const Text('تۆمارکراو (ئامادەکاری)'),
                  onSelected: (_) =>
                      setState(() => _selectedWhatsAppStatus = 'SIMULATED'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _selectedWhatsAppStatus == 'FAILED',
                  label: const Text('سەرکەوتوو نەبوو'),
                  onSelected: (_) =>
                      setState(() => _selectedWhatsAppStatus = 'FAILED'),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(whatsAppLogsProvider(filters));
            },
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('هەڵە لە بارکردنی لۆگەکان: $error')),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('هیچ مێژوویەکی وەتسئاپ بەردەست نییە'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: logs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildWhatsAppLogCard(context, log);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppLogCard(BuildContext context, WhatsAppLog log) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    log.recipientName ?? log.recipientPhone,
                    style: AppTextStyles.bodyBold,
                  ),
                ],
              ),
              StatusBadge(
                label: log.statusLabelKurdish,
                type: log.statusBadgeType,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('ژمارە: ${log.recipientPhone}', style: AppTextStyles.caption),
          const SizedBox(height: 8),

          // Message Preview Container
          Container(
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              log.message,
              style: AppTextStyles.caption.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),

          if (log.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              'هەڵە: ${log.errorMessage}',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${log.createdAt.year}/${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour}:${log.createdAt.minute}',
                style: AppTextStyles.caption,
              ),
              if (log.status == 'FAILED')
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await ref
                          .read(notificationActionsProvider)
                          .retryWhatsApp(log.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('دووبارە ناردنەوە ئەنجامدرا'),
                        ),
                      );
                      ref.invalidate(whatsAppLogsProvider);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('نەتوانرا بنێردرێتەوە: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('دووبارە بنێرەوە'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
