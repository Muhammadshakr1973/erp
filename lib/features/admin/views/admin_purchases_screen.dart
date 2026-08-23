import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AdminPurchasesScreen extends StatelessWidget {
  const AdminPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بازاڕ و سەپاڵیەر', style: AppTextStyles.h2),
          actions: [
            IconButton(icon: const Icon(AppIcons.add), onPressed: () {}),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'پێویست بۆ کڕین'),
              Tab(text: 'پسوڵەکانی کڕین'),
              Tab(text: 'سەپاڵیەرەکان'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequirementsTab(context),
            _buildPurchaseOrdersTab(context),
            _buildSuppliersTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.danger),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('کاڵای پێویست ژمارە ${index + 1}', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    const Text('کۆگای سەرەکی • داواکراو: 50', style: AppTextStyles.caption),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_checkout, color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchaseOrdersTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final isReceived = index % 2 == 0;
        return AppCard(
          onTap: () {},
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(AppIcons.order),
            ),
            title: Text('پسوڵەی کڕین #500$index', style: AppTextStyles.bodyBold),
            subtitle: const Text('کۆمپانیای جێگر • 10 کاڵا', style: AppTextStyles.caption),
            trailing: StatusBadge(
              label: isReceived ? 'گەیشتووە' : 'چاوەڕوانە',
              type: isReceived ? StatusBadgeType.success : StatusBadgeType.warning,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return AppCard(
          onTap: () {},
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.store, color: Colors.grey),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سەپاڵیەری ${index + 1}', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    const Text('0750 123 4567 • هەولێر', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('قەرز', style: AppTextStyles.caption),
                  Text(
                    '2,000,000 د.ع',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
