import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('سڵاو، شۆفێر', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notifications),
            onPressed: () {
              context.push('/notifications');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth >= 1024) crossAxisCount = 4;
                else if (constraints.maxWidth >= 600) crossAxisCount = 3;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                      context: context,
                      title: 'گەشتەکانی ئەمڕۆ',
                      value: '2',
                      icon: AppIcons.orderStatus,
                      color: AppColors.info,
                    ),
                    _buildStatCard(
                      context: context,
                      title: 'پسوڵەی گەیەنراو',
                      value: '14 / 20',
                      icon: AppIcons.orderDelivered,
                      color: AppColors.success,
                    ),
                    _buildStatCard(
                      context: context,
                      title: 'پارەی وەرگیراو',
                      value: '450,000 د.ع',
                      icon: AppIcons.customerDebt,
                      color: AppColors.primary,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}
