import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class SalesmanOrdersScreen extends StatelessWidget {
  const SalesmanOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پسوڵەکانی من', style: AppTextStyles.h2),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ئەمڕۆ'),
              Tab(text: 'ڕابردوو'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(context, true),
            _buildOrdersList(context, false),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, bool isToday) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: isToday ? 5 : 15,
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
                    Text('کڕیاری ژمارە ${index + 1}', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    Text(
                      'پسوڵەی #100${index + 1} • ${isToday ? 'ئەمڕۆ' : 'دوێنێ'}', 
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('125,000 د.ع', style: AppTextStyles.price),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: index % 3 == 0 ? 'DRAFT' : 'CONFIRMED',
                    type: index % 3 == 0 ? StatusBadgeType.warning : StatusBadgeType.success,
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
