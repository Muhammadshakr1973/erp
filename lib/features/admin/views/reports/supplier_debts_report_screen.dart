import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../products/providers/suppliers_provider.dart';
import '../providers/reports_provider.dart';

class SupplierDebtsReportScreen extends ConsumerStatefulWidget {
  const SupplierDebtsReportScreen({super.key});

  @override
  ConsumerState<SupplierDebtsReportScreen> createState() => _SupplierDebtsReportScreenState();
}

class _SupplierDebtsReportScreenState extends ConsumerState<SupplierDebtsReportScreen> {
  int? _selectedSupplierId;
  String? _selectedEntryType;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Create a map to trigger the future provider with current filters
  Map<String, dynamic> _filters = {};

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedSupplierId != null) 'supplier_id': _selectedSupplierId.toString(),
        if (_selectedEntryType != null && _selectedEntryType != 'ALL') 'entry_type': _selectedEntryType,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSupplierId = null;
      _selectedEntryType = null;
      _startDate = null;
      _endDate = null;
      _filters = {};
    });
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

  Widget _buildSupplierDropdown(AsyncValue<List<SupplierModel>> suppliersAsync) {
    return DropdownButtonFormField<int?>(
      value: _selectedSupplierId,
      decoration: const InputDecoration(
        labelText: 'کۆمپانیا',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت کۆمپانیاکان')),
        ...suppliersAsync.when(
          data: (suppliers) => suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          loading: () => [const DropdownMenuItem(value: null, child: Text('بارکردن...'))],
          error: (_, __) => [const DropdownMenuItem(value: null, child: Text('کێشە هەیە'))],
        ),
      ],
      onChanged: (val) => setState(() => _selectedSupplierId = val),
    );
  }

  Widget _buildEntryTypeDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedEntryType,
      decoration: const InputDecoration(
        labelText: 'جۆری جوڵە',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('گشتی')),
        DropdownMenuItem(value: 'PAYMENT', child: Text('پارەدان')),
        DropdownMenuItem(value: 'PURCHASE', child: Text('کڕین')),
        DropdownMenuItem(value: 'ADJUSTMENT', child: Text('ڕاستکردنەوە')),
      ],
      onChanged: (val) => setState(() => _selectedEntryType = val),
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
        child: Text(_startDate != null ? _startDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
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
        child: Text(_endDate != null ? _endDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(supplierDebtsReportProvider(_filters));
    final suppliersAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی قەرزی کۆمپانیاکان', style: AppTextStyles.h2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          children: [
            // Filter Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('فلتەرکردن', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      
                      if (isMobile) {
                        return Column(
                          children: [
                            _buildSupplierDropdown(suppliersAsync),
                            const SizedBox(height: AppSpacing.md),
                            _buildEntryTypeDropdown(),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(child: _buildStartDatePicker(context)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: _buildEndDatePicker(context)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: 'جێبەجێکردن',
                                onPressed: _applyFilters,
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(flex: 2, child: _buildSupplierDropdown(suppliersAsync)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(flex: 1, child: _buildEntryTypeDropdown()),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(flex: 1, child: _buildStartDatePicker(context)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(flex: 1, child: _buildEndDatePicker(context)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
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
            
            // Results Table
            Expanded(
              child: AppCard(
                child: reportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('هەڵەیەک ڕوویدا: $e')),
                  data: (ledgers) {
                    if (ledgers.isEmpty) {
                      return const Center(child: Text('هیچ داتایەک نەدۆزرایەوە', style: AppTextStyles.h3));
                    }
                    
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingTextStyle: AppTextStyles.bodyBold,
                          dataTextStyle: AppTextStyles.bodyMedium,
                          columns: const [
                            DataColumn(label: Text('بەروار')),
                            DataColumn(label: Text('کۆمپانیا')),
                            DataColumn(label: Text('جۆری جوڵە')),
                            DataColumn(label: Text('بڕی جوڵە')),
                            DataColumn(label: Text('قەرزی ماوە')),
                            DataColumn(label: Text('تێبینی')),
                          ],
                          rows: ledgers.map((entry) {
                            final isCredit = entry.type == 'credit';
                            final amountColor = isCredit ? AppColors.success : AppColors.danger;
                            
                            String entryTypeLabel = entry.entryType;
                            if (entryTypeLabel == 'PAYMENT') entryTypeLabel = 'پارەدان';
                            if (entryTypeLabel == 'PURCHASE') entryTypeLabel = 'کڕین';
                            if (entryTypeLabel == 'ADJUSTMENT') entryTypeLabel = 'ڕاستکردنەوە/قەرزی سەرەتا';
                            
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.createdAt?.split('T').first ?? '')),
                                DataCell(Text(entry.supplierName ?? 'نەزانراو')),
                                DataCell(Text(entryTypeLabel)),
                                DataCell(
                                  Text(
                                    '${isCredit ? '+' : '-'}${_formatCurrency(entry.amount)}',
                                    style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatCurrency(entry.balanceAfter),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                DataCell(Text(entry.description ?? '')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
