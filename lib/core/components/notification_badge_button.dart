import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

class NotificationBadgeButton extends ConsumerWidget {
  final Color? color;

  const NotificationBadgeButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep notifications list provider active so Pusher notifications are received in real-time
    ref.watch(notificationsListProvider);

    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: 'ئاگادارکردنەوەکان',
      onPressed: () {
        context.push('/notifications');
      },
      icon: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(AppIcons.notifications, color: color),
          if (unreadCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
