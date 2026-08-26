import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'reports/supplier_debts_report_screen.dart';
import 'reports/customer_debts_report_screen.dart';
import 'reports/payments_history_report_screen.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتەکان', style: AppTextStyles.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          _buildReportCategory(
            context,
            'فرۆشتن و قازانج',
            Icons.bar_chart,
            AppColors.primary,
            ['ڕاپۆرتی فرۆشتنی ئەمڕۆ', 'ڕاپۆرتی قازانجی مانگانە', 'فرۆشتن بەپێی مەندوب'],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'قەرزەکان',
            AppIcons.customerDebt,
            AppColors.danger,
            ['قەرزی کڕیارەکان', 'قەرزی کۆمپانیاکان', 'مێژووی پارەدان'],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'کۆمسیۆن و مەندوب',
            Icons.percent,
            AppColors.purple,
            ['ڕاپۆرتی کۆمسیۆنی مەندوبەکان', 'پوختەی کۆمسیۆنی مانگانە'],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'کۆگا و ستۆک',
            Icons.inventory_2_outlined,
            AppColors.info,
            ['ڕاپۆرتی کاڵا کەمبووەکان', 'جوڵەی ستۆک', 'ڕاپۆرتی گواستنەوەی کۆگاکان'],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategory(BuildContext context, String title, IconData icon, Color color, List<String> reports) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...reports.map((report) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () {
                    if (report == 'قەرزی کۆمپانیاکان') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupplierDebtsReportScreen()),
                      );
                    } else if (report == 'قەرزی کڕیارەکان') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerDebtsReportScreen()),
                      );
                    } else if (report == 'مێژووی پارەدان') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentsHistoryReportScreen()),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(report, style: AppTextStyles.bodyMedium),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
