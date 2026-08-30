import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    AppIcons.profile,
                    size: 50,
                    color: theme.colorScheme.primary,
                  ),
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
                    value: theme.brightness == Brightness.dark,
                    onChanged: (val) {
                      // Toggle Theme
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
