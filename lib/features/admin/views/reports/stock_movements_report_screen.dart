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

class StockMovementsReportScreen extends ConsumerStatefulWidget {
  const StockMovementsReportScreen({super.key});

  @override
  ConsumerState<StockMovementsReportScreen> createState() =>
      _StockMovementsReportScreenState();
}

class _StockMovementsReportScreenState
    extends ConsumerState<StockMovementsReportScreen> {
  int? _selectedWarehouseId;
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedWarehouseId != null)
          'warehouse_id': _selectedWarehouseId.toString(),
        if (_selectedType != null && _selectedType != 'ALL')
          'type': _selectedType,
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedWarehouseId = null;
      _selectedType = null;
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
      _filters = {
        'start_date': _startDate!.toIso8601String().split('T').first,
        'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(stockMovementsReportProvider(_filters));
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی جوڵەی ستۆک', style: AppTextStyles.h2),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فلتەرکردنی جوڵەی ستۆک',
                        style: AppTextStyles.h3,
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text(
                          'پاککردنەوە',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 700;
                      if (isMobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildStartDatePicker(context)),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: _buildEndDatePicker(context)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildWarehouseDropdown(warehousesAsync),
                            const SizedBox(height: AppSpacing.sm),
                            _buildTypeDropdown(),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: 'جێبەجێکردنی فلتەر',
                                onPressed: _applyFilters,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: _buildStartDatePicker(context)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _buildEndDatePicker(context)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildWarehouseDropdown(warehousesAsync),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _buildTypeDropdown()),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              text: 'جێبەجێکردن',
                              onPressed: _applyFilters,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                      ref.invalidate(stockMovementsReportProvider(_filters)),
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
                                'کۆی جوڵەکان',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.totalTransactions}',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.primary,
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
                                'کۆی هاتوو (+)',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${data.totalQuantityIn}',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.success,
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
                                'کۆی دەرچوو (-)',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '-${data.totalQuantityOut}',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Table
                  const Text('مێژووی جوڵەی کاڵاکان', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTable(data.transactions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<dynamic> transactions) {
    if (transactions.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'هیچ جوڵەیەکی ستۆک نەدۆزرایەوە',
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
            DataColumn(label: Text('بەروار')),
            DataColumn(label: Text('کۆگا')),
            DataColumn(label: Text('ناوی کاڵا')),
            DataColumn(label: Text('کۆد / SKU')),
            DataColumn(label: Text('جۆری جوڵە')),
            DataColumn(label: Text('گۆڕانکاری')),
            DataColumn(label: Text('ماوەی دوای جوڵە')),
            DataColumn(label: Text('تێبینی')),
          ],
          rows: transactions.map((t) {
            final isPositive = t.quantityChange > 0;
            return DataRow(
              cells: [
                DataCell(Text(t.createdAt.split('T').first)),
                DataCell(Text(t.warehouseName)),
                DataCell(
                  Text(
                    t.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(t.sku)),
                DataCell(Text(t.type)),
                DataCell(
                  Text(
                    '${isPositive ? '+' : ''}${t.quantityChange} ${t.unit}',
                    style: TextStyle(
                      color: isPositive ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text('${t.quantityAfter} ${t.unit}')),
                DataCell(Text(t.notes ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStartDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, true),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'لە بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          _startDate != null
              ? _startDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
        ),
      ),
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, false),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'تا بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          _endDate != null
              ? _endDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
        ),
      ),
    );
  }

  Widget _buildWarehouseDropdown(
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedWarehouseId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'کۆگا',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت کۆگاکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final w in warehousesAsync.valueOrNull ?? <WarehouseModel>[])
          DropdownMenuItem<int?>(
            value: w.id,
            child: Text(
              w.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedWarehouseId = val),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'جۆری جوڵە',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
          value: 'ALL',
          child: Text('گشتی', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'PURCHASE',
          child: Text('کڕین (Purchase)', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'SALE',
          child: Text('فرۆشتن (Sale)', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'TRANSFER_IN',
          child: Text('گواستنەوە بۆ ناوەوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'TRANSFER_OUT',
          child: Text('گواستنەوە بۆ دەرەوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'ADJUSTMENT',
          child: Text('ڕێکخستن (Adjustment)', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'RETURN',
          child: Text('گەڕانەوە (Return)', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (val) => setState(() => _selectedType = val),
    );
  }
}
