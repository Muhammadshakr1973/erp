import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/warehouse_provider.dart';
import '../providers/reports_provider.dart';

class LowStockReportScreen extends ConsumerStatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  ConsumerState<LowStockReportScreen> createState() =>
      _LowStockReportScreenState();
}

class _LowStockReportScreenState extends ConsumerState<LowStockReportScreen> {
  int? _selectedWarehouseId;
  bool _isFilterExpanded = false;
  Map<String, dynamic> _filters = {};

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedWarehouseId != null)
          'warehouse_id': _selectedWarehouseId.toString(),
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
    return Formatters.currency(amount);
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(lowStockReportProvider(_filters));
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'کاڵا کەمبووەکان (Low Stock)',
          style: AppTextStyles.h2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'فلتەرکردنی کۆگا',
                                style: AppTextStyles.h3,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _isFilterExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: AppColors.textSecondaryLight,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isFilterExpanded = !_isFilterExpanded;
                                  });
                                },
                                icon: Icon(
                                  _isFilterExpanded ? Icons.close : Icons.filter_alt_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  _isFilterExpanded ? 'داخستن' : 'فلتەرکردن',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_selectedWarehouseId != null)
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text(
                                    'پاککردنەوە',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isFilterExpanded) ...[
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isFilterExpanded = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: AppColors.borderLight.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedWarehouseId != null
                                    ? 'فلتەری کۆگا دیاریکراوە'
                                    : 'گشت کۆگاکان',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            const Row(
                              children: [
                                Text(
                                  'دەستکاریکردنی فلتەر',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedWarehouseId,
                            decoration: const InputDecoration(
                              labelText: 'کۆگا',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('گشت کۆگاکان'),
                              ),
                              for (final w in warehousesAsync.valueOrNull ?? <WarehouseModel>[])
                                DropdownMenuItem<int?>(
                                  value: w.id,
                                  child: Text(w.name),
                                ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedWarehouseId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'جێبەجێکردنی فلتەر',
                        icon: Icons.check,
                        onPressed: () {
                          _applyFilters();
                          setState(() {
                            _isFilterExpanded = false;
                          });
                        },
                      ),
                    ),
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
                child: ErrorState(
                  title: 'هەڵەیەک ڕوویدا',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () =>
                      ref.invalidate(lowStockReportProvider(_filters)),
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
                              const Text(
                                'ژمارەی کاڵا کەمبووەکان',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.totalLowStockItems} کاڵا',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                              const Text(
                                'تێچووی پێشبینیکراوی پڕکردنەوە',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(data.estimatedReorderCost),
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Table
                  const Text(
                    'لیستی هۆشداری کەمبوونەوەی کاڵا',
                    style: AppTextStyles.h3,
                  ),
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

  Widget _buildTable(List<dynamic> items) {
    if (items.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'هیچ کاڵایەک کەم نەبووەتەوە! ستۆکی هەموو کاڵاکان باشە.',
              style: AppTextStyles.bodyMedium,
            ),
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
            return DataRow(
              cells: [
                DataCell(Text(item.warehouseName)),
                DataCell(
                  Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(item.sku)),
                DataCell(Text(item.categoryName)),
                DataCell(Text(item.supplierName)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.availableQuantity} ${item.unit}',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text('${item.reservedQuantity}')),
                DataCell(Text('${item.minStockLevel}')),
                DataCell(
                  Text(
                    '${item.suggestedReorder} ${item.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(item.estimatedCost),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
