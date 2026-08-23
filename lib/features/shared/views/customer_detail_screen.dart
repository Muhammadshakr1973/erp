import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('زانیاری کڕیار', style: AppTextStyles.h2),
          actions: [
            IconButton(icon: const Icon(AppIcons.edit), onPressed: () {}),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'زانیاری'),
              Tab(text: 'قەرز (Ledger)'),
              Tab(text: 'پسوڵەکان'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfoTab(context),
            _buildLedgerTab(context),
            _buildOrdersTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(AppIcons.customer, size: 40, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text('مارکێتی ئەحمەد', style: AppTextStyles.displayMedium),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppCard(
            child: Column(
              children: [
                _buildInfoRow(context, Icons.phone, '0750 123 4567'),
                const Divider(),
                _buildInfoRow(context, Icons.location_on, 'گەڕەکی بەختیاری، شەقامی ١٠٠ مەتری'),
                const Divider(),
                _buildInfoRow(context, Icons.sell, 'جۆری نرخ: N1 (هەرزان)'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('کۆی قەرزی ئێستا', style: AppTextStyles.bodyLarge),
                Text('450,000 د.ع', style: AppTextStyles.priceLarge.copyWith(color: AppColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 10,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final isPayment = index % 3 == 0;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isPayment ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
            child: Icon(
              isPayment ? Icons.arrow_downward : Icons.arrow_upward,
              color: isPayment ? AppColors.success : AppColors.danger,
            ),
          ),
          title: Text(isPayment ? 'پارەدان (پێشەکی)' : 'پسوڵەی فرۆشتن #100$index', style: AppTextStyles.bodyBold),
          subtitle: const Text('2026-08-23', style: AppTextStyles.caption),
          trailing: Text(
            isPayment ? '+ 50,000 د.ع' : '- 125,000 د.ع',
            style: AppTextStyles.price.copyWith(
              color: isPayment ? AppColors.success : AppColors.danger,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.order),
            title: Text('پسوڵەی #100$index', style: AppTextStyles.bodyBold),
            subtitle: const Text('3 کاڵا', style: AppTextStyles.caption),
            trailing: Text('125,000 د.ع', style: AppTextStyles.price),
          ),
        );
      },
    );
  }
}
