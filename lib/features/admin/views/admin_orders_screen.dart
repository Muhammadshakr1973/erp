import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('هەموو پسوڵەکان', style: AppTextStyles.h2),
          actions: [
            IconButton(icon: const Icon(AppIcons.filter), onPressed: () {}),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'هەمووی'),
              Tab(text: 'لە گەیاندن'),
              Tab(text: 'گەیشتووە'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(context, 'هەمووی'),
            _buildOrdersList(context, 'لە گەیاندن'),
            _buildOrdersList(context, 'گەیشتووە'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, String filter) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 10,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return AppCard(
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(AppIcons.order, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مارکێتی ژمارە ${index + 1}', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    Text(
                      'پسوڵەی #100${index + 1} • مەندوب: محەمەد', 
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('250,000 د.ع', style: AppTextStyles.price),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: index % 2 == 0 ? 'گەیشتووە' : 'ئامادەکردن',
                    type: index % 2 == 0 ? StatusBadgeType.success : StatusBadgeType.warning,
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
