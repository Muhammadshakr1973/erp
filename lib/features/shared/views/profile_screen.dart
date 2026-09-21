import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/customer_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/sync/sync_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('پڕۆفایل', style: AppTextStyles.h2)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Center(
            child: Column(
              children: [
                CustomerAvatar(
                  imageUrl: user?.imageUrl,
                  size: 100,
                  borderRadius: 32,
                  placeholderIcon: AppIcons.profile,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  iconColor: theme.colorScheme.primary,
                  iconSize: 50,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(user?.name ?? 'ناوی بەکارهێنەر', style: AppTextStyles.h2),
                Text(
                  user?.role.toUpperCase() ?? 'ROLE',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.phone ?? '0750 000 0000',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const Text('ڕێکخستنەکان', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('زمان', style: AppTextStyles.bodyBold),
                  trailing: const Text(
                    'کوردی (سۆرانی)',
                    style: AppTextStyles.caption,
                  ),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text(
                    'دۆخی تاریک',
                    style: AppTextStyles.bodyBold,
                  ),
                  trailing: Switch(
                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).toggleTheme();
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text(
                    'گۆڕینی وشەی نهێنی',
                    style: AppTextStyles.bodyBold,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.sync_problem, color: AppColors.danger),
                  title: const Text(
                    'پاککردنەوەی هەڵەکانی سینک',
                    style: AppTextStyles.bodyBold,
                  ),
                  subtitle: const Text(
                    'ئەو کردارانەی تووشی هەڵە بوون لە ڕیز لادەبات بۆ نەهێشتنی باڕی سوور',
                    style: AppTextStyles.caption,
                  ),
                  trailing: const Icon(Icons.delete_sweep, color: AppColors.danger),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('دڵنیابوونەوە', style: AppTextStyles.h2),
                        content: const Text(
                          'ئایا دڵنیایت لە پاککردنەوەی هەموو هەڵەکانی سینک؟ ئەم کردارە ئەو داتایانەی پێشتر لە ناردن فاشل بوون لادەبات لە ڕیزی ناردن.',
                          style: AppTextStyles.bodyMedium,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('پاشگەزبوونەوە'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: const Text('سڕینەوە و پاککردنەوە'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.clearFailedOperations();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('سەرجەم هەڵەکانی سینک بە سەرکەوتوویی پاککرانەوە.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppButton(
            text: 'چوونەدەرەوە',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            // Using outline or danger style manually if needed, otherwise secondary
            size: AppButtonSize.lg,
          ),
        ],
      ),
    );
  }
}
