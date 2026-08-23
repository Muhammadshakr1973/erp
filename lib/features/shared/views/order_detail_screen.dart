import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_breakpoints.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.desktopMin;

    return Scaffold(
      appBar: AppBar(
        title: Text('پسوڵەی #$orderId', style: AppTextStyles.h2),
        actions: [
          IconButton(icon: const Icon(Icons.print_outlined), onPressed: () {}),
          IconButton(icon: const Icon(AppIcons.edit), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildMainContent(context)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 1, child: _buildSidePanel(context)),
                ],
              )
            : Column(
                children: [
                  _buildMainContent(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildSidePanel(context),
                ],
              ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کاڵاکان', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('شامپۆی سەر، قەبارەی گەورە', style: AppTextStyles.bodyBold),
                    subtitle: const Text('2 کارتۆن x 15,000 د.ع', style: AppTextStyles.caption),
                    trailing: Text('30,000 د.ع', style: AppTextStyles.price),
                  );
                },
              ),
              const Divider(thickness: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی گشتی', style: AppTextStyles.bodyLarge),
                    Text('120,000 د.ع', style: AppTextStyles.priceLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('زانیاری پسوڵە', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow('کڕیار', 'مارکێتی ئەحمەد'),
              _buildInfoRow('مەندوب', 'محەمەد عەلی'),
              _buildInfoRow('بەروار', '2026-08-23 10:30 AM'),
              const SizedBox(height: AppSpacing.sm),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('دۆخ', style: AppTextStyles.bodyMedium),
                  StatusBadge(label: 'CONFIRMED', type: StatusBadgeType.success),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('پارەدان', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow('کۆی گشتی', '120,000 د.ع'),
              _buildInfoRow('پارەی دراو', '50,000 د.ع'),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ماوە', style: AppTextStyles.bodyBold),
                  Text('70,000 د.ع', style: AppTextStyles.price.copyWith(color: AppColors.danger)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
