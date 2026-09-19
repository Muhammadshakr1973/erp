import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/customer_provider.dart';
import '../../../shared/models/customer.dart';
import '../providers/reports_provider.dart';

class CustomerDebtsReportScreen extends ConsumerStatefulWidget {
  const CustomerDebtsReportScreen({super.key});

  @override
  ConsumerState<CustomerDebtsReportScreen> createState() =>
      _CustomerDebtsReportScreenState();
}

class _CustomerDebtsReportScreenState
    extends ConsumerState<CustomerDebtsReportScreen> {
  int? _selectedCustomerId;
  String? _selectedEntryType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterExpanded = false;

  // Create a map to trigger the future provider with current filters
  Map<String, dynamic> _filters = {};

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedCustomerId != null)
          'customer_id': _selectedCustomerId.toString(),
        if (_selectedEntryType != null && _selectedEntryType != 'ALL')
          'entry_type': _selectedEntryType,
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCustomerId = null;
      _selectedEntryType = null;
      _startDate = null;
      _endDate = null;
      _filters = {};
    });
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
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

  Widget _buildCustomerDropdown(AsyncValue<List<Customer>> customersAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedCustomerId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'کڕیار',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت کڕیارەکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final s in customersAsync.valueOrNull ?? <Customer>[])
          DropdownMenuItem<int?>(
            value: s.id,
            child: Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedCustomerId = val),
    );
  }

  Widget _buildEntryTypeDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedEntryType,
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
          value: 'PAYMENT',
          child: Text('پارەدان', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'SALE',
          child: Text('فرۆشتن', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'ADJUSTMENT',
          child: Text('ڕاستکردنەوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
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

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(customerDebtsReportProvider(_filters));
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی قەرزی کڕیارکان', style: AppTextStyles.h2),
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
                        children: [
                          const Icon(
                            Icons.tune,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'فلتەرکردنی ڕاپۆرت',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'پاککردنەوە',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _isFilterExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                              size: 18,
                            ),
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
                          children: [
                            Expanded(
                              child: Text(
                                _startDate != null || _endDate != null || _selectedCustomerId != null
                                    ? 'فلتەری چالاک هەیە (${_startDate?.toIso8601String().split('T').first ?? 'دەستپێک'} بۆ ${_endDate?.toIso8601String().split('T').first ?? 'کۆتایی'})'
                                    : 'گشت کڕیارەکان و بەروارەکان',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'دەستکاریکردن',
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;

                        if (isMobile) {
                          return Column(
                            children: [
                              _buildCustomerDropdown(customersAsync),
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
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildCustomerDropdown(customersAsync),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 1,
                              child: _buildEntryTypeDropdown(),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 1,
                              child: _buildStartDatePicker(context),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 1,
                              child: _buildEndDatePicker(context),
                            ),
                          ],
                        );
                      },
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

            // Results Table
            Expanded(
              child: AppCard(
                child: reportAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: ErrorState(
                      title: 'هەڵەیەک ڕوویدا',
                      message: Formatters.cleanError(e),
                      retryText: 'دووبارە هەوڵبدەرەوە',
                      onRetry: () =>
                          ref.invalidate(customerDebtsReportProvider),
                    ),
                  ),
                  data: (ledgers) {
                    if (ledgers.isEmpty) {
                      return const Center(
                        child: Text(
                          'هیچ داتایەک نەدۆزرایەوە',
                          style: AppTextStyles.h3,
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingTextStyle: AppTextStyles.bodyBold,
                          dataTextStyle: AppTextStyles.bodyMedium,
                          columns: const [
                            DataColumn(label: Text('بەروار')),
                            DataColumn(label: Text('کڕیار')),
                            DataColumn(label: Text('جۆری جوڵە')),
                            DataColumn(label: Text('بڕی جوڵە')),
                            DataColumn(label: Text('قەرزی ماوە')),
                            DataColumn(label: Text('تێبینی')),
                          ],
                          rows: ledgers.map((entry) {
                            final isCredit = entry.type == 'credit';
                            final amountColor = isCredit
                                ? AppColors.success
                                : AppColors.danger;

                            String entryTypeLabel = entry.entryType;
                            if (entryTypeLabel == 'PAYMENT') {
                              entryTypeLabel = 'پارەدان';
                            } else if (entryTypeLabel == 'SALE') {
                              entryTypeLabel = 'فرۆشتن';
                            } else if (entryTypeLabel == 'ADJUSTMENT') {
                              entryTypeLabel = 'ڕاستکردنەوە/قەرزی سەرەتا';
                            }

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(entry.createdAt?.split('T').first ?? ''),
                                ),
                                DataCell(
                                  Text(entry.customerName ?? 'نەزانراو'),
                                ),
                                DataCell(Text(entryTypeLabel)),
                                DataCell(
                                  Text(
                                    '${isCredit ? '+' : '-'}${_formatCurrency(entry.amount)}',
                                    style: TextStyle(
                                      color: amountColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatCurrency(entry.balanceAfter),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
