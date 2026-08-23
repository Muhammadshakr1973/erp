import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class TripOrdersScreen extends StatelessWidget {
  final String tripId;

  const TripOrdersScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وردەکاری گەشت #$tripId', style: AppTextStyles.h2),
        actions: [
          IconButton(icon: const Icon(AppIcons.routeMap), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildTripSummary(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: 8,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final isDelivered = index < 3;
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('مارکێتی ژمارە ${index + 1}', style: AppTextStyles.bodyBold),
                          StatusBadge(
                            label: isDelivered ? 'گەیشتووە' : 'لە گەیاندنە',
                            type: isDelivered ? StatusBadgeType.success : StatusBadgeType.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('گەڕەکی بەختیاری', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('125,000 د.ع', style: AppTextStyles.price),
                          if (!isDelivered)
                            AppButton(
                              text: 'گەیشت',
                              size: AppButtonSize.sm,
                              onPressed: () {
                                // Mark as delivered & Collect payment
                              },
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

  Widget _buildTripSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('هەموو', '8'),
          _buildSummaryItem('گەیشتوو', '3', AppColors.success),
          _buildSummaryItem('ماوە', '5', AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h2.copyWith(color: color ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}
