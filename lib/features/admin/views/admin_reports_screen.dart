import 'package:flutter/material.dart';

import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'reports/supplier_debts_report_screen.dart';
import 'reports/customer_debts_report_screen.dart';
import 'reports/payments_history_report_screen.dart';
import 'reports/salesman_commissions_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/profit_report_screen.dart';
import 'reports/sales_by_salesman_report_screen.dart';
import 'reports/low_stock_report_screen.dart';
import 'reports/stock_movements_report_screen.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ڕاپۆرتەکان', style: AppTextStyles.h2)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          _buildReportCategory(
            context,
            'فرۆشتن و قازانج',
            Icons.bar_chart,
            AppColors.primary,
            [
              _ReportItem(
                'ڕاپۆرتی فرۆشتنی گشتی',
                () => const SalesReportScreen(),
              ),
              _ReportItem(
                'ڕاپۆرتی قازانجی کاڵاکان',
                () => const ProfitReportScreen(),
              ),
              _ReportItem(
                'فرۆشتن بەپێی مەندوب',
                () => const SalesBySalesmanReportScreen(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'قەرز و شایستەکان',
            AppIcons.customerDebt,
            AppColors.danger,
            [
              _ReportItem(
                'قەرزی کڕیارەکان',
                () => const CustomerDebtsReportScreen(),
              ),
              _ReportItem(
                'قەرزی کۆمپانیاکان',
                () => const SupplierDebtsReportScreen(),
              ),
              _ReportItem(
                'مێژووی پارەدان و وەرگرتن',
                () => const PaymentsHistoryReportScreen(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'کۆمسیۆن و مەندوب',
            Icons.percent,
            AppColors.purple,
            [
              _ReportItem(
                'ڕاپۆرتی کۆمسیۆنی مەندوبەکان',
                () => const SalesmanCommissionsReportScreen(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReportCategory(
            context,
            'کۆگا و ستۆک',
            Icons.inventory_2_outlined,
            AppColors.info,
            [
              _ReportItem(
                'ڕاپۆرتی کاڵا کەمبووەکان (Low Stock)',
                () => const LowStockReportScreen(),
              ),
              _ReportItem(
                'جوڵەی ستۆک (Stock Movements)',
                () => const StockMovementsReportScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategory(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<_ReportItem> reports,
  ) {
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
          ...reports.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => item.builder()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.title, style: AppTextStyles.bodyMedium),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final Widget Function() builder;

  _ReportItem(this.title, this.builder);
}
