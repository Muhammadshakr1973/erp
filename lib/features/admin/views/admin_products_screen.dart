import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵاکان و کۆگا', style: AppTextStyles.h2),
        actions: [
          IconButton(icon: const Icon(AppIcons.add), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hintText: 'گەڕان بۆ کاڵا، بارکۆد...',
                    prefixIcon: AppIcons.search,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: IconButton(
                    icon: const Icon(AppIcons.scan),
                    onPressed: () {},
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              itemCount: 20,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final int stock = index % 4 == 0 ? 5 : 150; // Simulate low stock
                final bool isLowStock = stock < 20;

                return AppCard(
                  onTap: () {},
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: NetworkImage('https://via.placeholder.com/150'), // Placeholder image
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('شامپۆی سەر ${index + 1}', style: AppTextStyles.bodyBold),
                            const SizedBox(height: 4),
                            Text('کارتۆن: 12 دانە • بارکۆد: 123456789', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('15,000 د.ع', style: AppTextStyles.price),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: 'ستۆک: $stock',
                            type: isLowStock ? StatusBadgeType.danger : StatusBadgeType.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
