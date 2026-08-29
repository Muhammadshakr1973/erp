import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/warehouse_provider.dart';
import '../../providers/reports_provider.dart';

class LowStockReportScreen extends ConsumerStatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  ConsumerState<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends ConsumerState<LowStockReportScreen> {
  int? _selectedWarehouseId;
  Map<String, dynamic> _filters = {};

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedWarehouseId != null) 'warehouse_id': _selectedWarehouseId.toString(),
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedWarehouseId = null;
      _filters = {};
    });
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(lowStockReportProvider(_filters));
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاڵا کەمبووەکان (Low Stock)', style: AppTextStyles.h2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedWarehouseId,
                      decoration: const InputDecoration(
                        labelText: 'کۆگا',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('گشت کۆگاکان')),
                        ...warehousesAsync.when(
                          data: (list) => list.map<DropdownMenuItem<int?>>((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                          loading: () => [],
                          error: (_, _) => [],
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedWarehouseId = val);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(text: 'نوێکردنەوە', onPressed: _applyFilters),
                  if (_selectedWarehouseId != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(onPressed: _clearFilters, child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Report Results
            reportAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('هەڵەیەک ڕوویدا: $err', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ژمارەی کاڵا کەمبووەکان', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 4),
                              Text('${data.totalLowStockItems} کاڵا', style: AppTextStyles.h3.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تێچووی پێشبینیکراوی پڕکردنەوە', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 4),
                              Text(_formatCurrency(data.estimatedReorderCost), style: AppTextStyles.h3.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Table
                  const Text('لیستی هۆشداری کەمبوونەوەی کاڵا', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTable(data.items),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List items) {
    if (items.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('هیچ کاڵایەک کەم نەبووەتەوە! ستۆکی هەموو کاڵاکان باشە.', style: AppTextStyles.bodyMedium),
          ),
        ),
      );
    }

    return AppCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTextStyles.bodyBold,
          dataTextStyle: AppTextStyles.bodyMedium,
          columns: const [
            DataColumn(label: Text('کۆگا')),
            DataColumn(label: Text('ناوی کاڵا')),
            DataColumn(label: Text('کۆد / SKU')),
            DataColumn(label: Text('پۆل')),
            DataColumn(label: Text('کۆمپانیا')),
            DataColumn(label: Text('ستۆکی بەردەست')),
            DataColumn(label: Text('حجزکراو')),
            DataColumn(label: Text('کەمترین ئاست')),
            DataColumn(label: Text('پێشنیاری داواکاری')),
            DataColumn(label: Text('تێچووی خەمڵێنراو')),
          ],
          rows: items.map((item) {
            return DataRow(cells: [
              DataCell(Text(item.warehouseName)),
              DataCell(Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(item.sku)),
              DataCell(Text(item.categoryName)),
              DataCell(Text(item.supplierName)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${item.availableQuantity} ${item.unit}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text('${item.reservedQuantity}')),
              DataCell(Text('${item.minStockLevel}')),
              DataCell(Text('${item.suggestedReorder} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_formatCurrency(item.estimatedCost), textDirection: TextDirection.ltr)),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
