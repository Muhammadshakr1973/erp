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
import '../../../products/providers/suppliers_provider.dart';
import '../../../products/models/supplier_model.dart';
import '../providers/reports_provider.dart';

class PaymentsHistoryReportScreen extends ConsumerStatefulWidget {
  const PaymentsHistoryReportScreen({super.key});

  @override
  ConsumerState<PaymentsHistoryReportScreen> createState() =>
      _PaymentsHistoryReportScreenState();
}

class _PaymentsHistoryReportScreenState
    extends ConsumerState<PaymentsHistoryReportScreen> {
  String _paymentType = 'customer'; // 'customer' or 'supplier'
  int? _selectedPartyId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterExpanded = false;

  Map<String, dynamic> _filters = {'type': 'customer'};

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filters = {
        'type': _paymentType,
        if (_selectedPartyId != null)
          _paymentType == 'customer' ? 'customer_id' : 'supplier_id':
              _selectedPartyId!.toString(),
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedPartyId = null;
      _startDate = null;
      _endDate = null;
      _filters = {'type': _paymentType};
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

  Widget _buildPartyDropdown(
    AsyncValue<List<Customer>> customersAsync,
    AsyncValue<List<SupplierModel>> suppliersAsync,
  ) {
    if (_paymentType == 'customer') {
      return DropdownButtonFormField<int?>(
        initialValue: _selectedPartyId,
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
        onChanged: (val) => setState(() => _selectedPartyId = val),
      );
    } else {
      return DropdownButtonFormField<int?>(
        initialValue: _selectedPartyId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'دابینکەر / کۆمپانیا',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text(
              'گشت کۆمپانیاکان',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final s in suppliersAsync.valueOrNull ?? <SupplierModel>[])
            DropdownMenuItem<int?>(
              value: s.id,
              child: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (val) => setState(() => _selectedPartyId = val),
      );
    }
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
    final reportAsync = ref.watch(paymentsHistoryReportProvider(_filters));
    final customersAsync = ref.watch(customerListProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی مێژووی پارەدان', style: AppTextStyles.h2),
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
                                '${_paymentType == 'customer' ? 'پارەدانی کڕیارەکان' : 'پارەدانی کۆمپانیاکان'} | ${_startDate != null || _endDate != null || _selectedPartyId != null ? 'فلتەری چالاک هەیە' : 'گشت لایەنەکان و بەروارەکان'}',
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
                    // Payment Type Selection (Tabs/Segmented Control style)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_paymentType != 'customer') {
                                  setState(() {
                                    _paymentType = 'customer';
                                    _selectedPartyId = null;
                                  });
                                }
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _paymentType == 'customer'
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'پارەدانی کڕیارەکان',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: _paymentType == 'customer'
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_paymentType != 'supplier') {
                                  setState(() {
                                    _paymentType = 'supplier';
                                    _selectedPartyId = null;
                                  });
                                }
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _paymentType == 'supplier'
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'پارەدانی کۆمپانیاکان',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: _paymentType == 'supplier'
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;

                        if (isMobile) {
                          return Column(
                            children: [
                              _buildPartyDropdown(customersAsync, suppliersAsync),
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
                              child: _buildPartyDropdown(
                                customersAsync,
                                suppliersAsync,
                              ),
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
                          ref.invalidate(paymentsHistoryReportProvider),
                    ),
                  ),
                  data: (payments) {
                    if (payments.isEmpty) {
                      return const Center(
                        child: Text(
                          'هیچ داتایەک نەدۆزرایەوە',
                          style: AppTextStyles.h3,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Brief statistics summary
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'کۆی پسوڵەکان: ${payments.length}',
                                style: AppTextStyles.bodyBold,
                              ),
                              Text(
                                'کۆی پارەی وەرگیراو/دراو: ${_formatCurrency(payments.fold<num>(0, (prev, element) => prev + element.amount))}',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingTextStyle: AppTextStyles.bodyBold,
                                dataTextStyle: AppTextStyles.bodyMedium,
                                columns: [
                                  const DataColumn(label: Text('بەروار')),
                                  DataColumn(
                                    label: Text(
                                      _paymentType == 'customer'
                                          ? 'کڕیار'
                                          : 'کۆمپانیا',
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text('شێوازی پارەدان'),
                                  ),
                                  const DataColumn(label: Text('بڕی پارە')),
                                  const DataColumn(
                                    label: Text('سەرچاوە/ڕوونکردنەوە'),
                                  ),
                                  const DataColumn(label: Text('تێبینی')),
                                ],
                                rows: payments.map((payment) {
                                  final isCustomer = payment.type == 'customer';
                                  final amountColor = isCustomer
                                      ? AppColors.success
                                      : AppColors.danger;

                                  String methodLabel = payment.paymentMethod;
                                  if (methodLabel == 'CASH') {
                                    methodLabel = 'نەختینە (کاش)';
                                  } else if (methodLabel == 'BANK') {
                                    methodLabel = 'بانک';
                                  } else if (methodLabel == 'TRANSFER') {
                                    methodLabel = 'حەواڵە';
                                  }

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(payment.paidAt.split('T').first),
                                      ),
                                      DataCell(Text(payment.partyName)),
                                      DataCell(Text(methodLabel)),
                                      DataCell(
                                        Text(
                                          _formatCurrency(payment.amount),
                                          style: TextStyle(
                                            color: amountColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ),
                                      DataCell(Text(payment.reference)),
                                      DataCell(Text(payment.notes ?? '')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
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
