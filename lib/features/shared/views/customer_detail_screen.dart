import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api_client.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../../admin/views/providers/reports_provider.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  String? _ledgerEntryType;
  DateTime? _ledgerStartDate;
  DateTime? _ledgerEndDate;
  Map<String, dynamic> _ledgerFilters = {};

  final _paymentFormKey = GlobalKey<FormState>();
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _ledgerFilters = {'customer_id': widget.customerId};
  }

  void _applyLedgerFilters() {
    setState(() {
      _ledgerFilters = {
        'customer_id': widget.customerId,
        if (_ledgerEntryType != null && _ledgerEntryType != 'ALL') 'entry_type': _ledgerEntryType,
        if (_ledgerStartDate != null) 'start_date': _ledgerStartDate!.toIso8601String().split('T').first,
        if (_ledgerEndDate != null) 'end_date': _ledgerEndDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearLedgerFilters() {
    setState(() {
      _ledgerEntryType = null;
      _ledgerStartDate = null;
      _ledgerEndDate = null;
      _ledgerFilters = {'customer_id': widget.customerId};
    });
  }

  Future<void> _selectLedgerDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _ledgerStartDate = picked;
        } else {
          _ledgerEndDate = picked;
        }
      });
    }
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _showPaymentDialog(BuildContext context, Customer customer) async {
    _paymentAmountController.clear();
    _paymentNotesController.clear();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تۆمارکردنی پارەدان', style: AppTextStyles.h2),
            content: Form(
              key: _paymentFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: _paymentAmountController,
                    labelText: 'بڕی پارە (د.ع)',
                    prefixIcon: Icons.money,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'تکایە بڕی پارە بنووسە';
                      if (int.tryParse(val) == null) return 'بڕی پارە نادروستە';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _paymentNotesController,
                    labelText: 'تێبینی',
                    prefixIcon: Icons.note,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
              ),
              AppButton(
                text: 'تۆمارکردن',
                isLoading: _isPaying,
                onPressed: () async {
                  if (_paymentFormKey.currentState!.validate()) {
                    setStateDialog(() => _isPaying = true);
                    try {
                      final api = ref.read(apiClientProvider);
                      final response = await api.client.post('/payments', data: {
                        'customer_id': customer.id,
                        'amount': int.parse(_paymentAmountController.text),
                        'notes': _paymentNotesController.text,
                        'payment_method': 'CASH',
                      });
                      
                      if (response.statusCode == 201) {
                        ref.invalidate(singleCustomerProvider(customer.id));
                        ref.invalidate(customerDebtsReportProvider(_ledgerFilters));
                        ref.invalidate(customerListProvider);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('پارەدانەکە بەسەرکەوتوویی تۆمارکرا')),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('هەڵە ڕوویدا: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    } finally {
                      setStateDialog(() => _isPaying = false);
                    }
                  }
                },
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerIdInt = int.tryParse(widget.customerId) ?? 0;
    final customerAsync = ref.watch(singleCustomerProvider(customerIdInt));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('زانیاری کڕیار', style: AppTextStyles.h2),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'زانیاری'),
              Tab(text: 'قەرز (Ledger)'),
              Tab(text: 'پسوڵەکان'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: customerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('هەڵە ڕوویدا: $e')),
          data: (customer) => TabBarView(
            children: [
              _buildInfoTab(context, customer),
              _buildLedgerTab(context, customer),
              _buildOrdersTab(context, customer),
            ],
          ),
        ),
        floatingActionButton: customerAsync.maybeWhen(
          data: (customer) => FloatingActionButton.extended(
            onPressed: () => _showPaymentDialog(context, customer),
            icon: const Icon(Icons.payment),
            label: const Text('پارەدان'),
            backgroundColor: AppColors.primary,
          ),
          orElse: () => null,
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context, Customer customer) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(AppIcons.customer, size: 40, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(customer.name, style: AppTextStyles.displayMedium),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppCard(
            child: Column(
              children: [
                _buildInfoRow(context, Icons.phone, customer.phone ?? 'بێ ژمارە'),
                const Divider(),
                _buildInfoRow(context, Icons.location_on, customer.address ?? 'بێ ناونیشان'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('کۆی قەرزی ئێستا', style: AppTextStyles.bodyLarge),
                Text(
                  _formatCurrency(customer.balance), 
                  style: AppTextStyles.priceLarge.copyWith(color: customer.balance > 0 ? AppColors.danger : AppColors.success)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context, Customer customer) {
    final ledgerAsync = ref.watch(customerDebtsReportProvider(_ledgerFilters));
    
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // Filter UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _ledgerEntryType,
                        decoration: const InputDecoration(
                          labelText: 'جۆری جوڵە',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('گشتی')),
                          DropdownMenuItem(value: 'PAYMENT', child: Text('پارەدان')),
                          DropdownMenuItem(value: 'SALE', child: Text('فرۆشتن')),
                          DropdownMenuItem(value: 'RETURN', child: Text('گەڕانەوە')),
                          DropdownMenuItem(value: 'ADJUSTMENT', child: Text('ڕاستکردنەوە')),
                        ],
                        onChanged: (val) => setState(() => _ledgerEntryType = val),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectLedgerDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'لە بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(_ledgerStartDate != null ? _ledgerStartDate!.toIso8601String().split('T').first : 'دیارینەکراوە', style: AppTextStyles.caption),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectLedgerDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تا بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(_ledgerEndDate != null ? _ledgerEndDate!.toIso8601String().split('T').first : 'دیارینەکراوە', style: AppTextStyles.caption),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _clearLedgerFilters,
                      child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
                    ),
                    SizedBox(
                      width: 120,
                      child: AppButton(
                        text: 'فلتەر',
                        onPressed: _applyLedgerFilters,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ledgerAsync.when(
            data: (ledgerList) {
              if (ledgerList.isEmpty) {
                return const Center(child: Text('هیچ مێژوویەک نییە'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                itemCount: ledgerList.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = ledgerList[index];
                  final isCredit = entry.type == 'credit';
                  final amountColor = isCredit ? AppColors.success : AppColors.danger;
                  
                  String entryTypeLabel = entry.entryType;
                  if (entryTypeLabel == 'PAYMENT') entryTypeLabel = 'پارەدان';
                  if (entryTypeLabel == 'SALE') entryTypeLabel = 'فرۆشتن';
                  if (entryTypeLabel == 'RETURN') entryTypeLabel = 'گەڕانەوە';
                  if (entryTypeLabel == 'ADJUSTMENT') entryTypeLabel = 'ڕاستکردنەوە/قەرزی سەرەتا';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.description ?? entryTypeLabel, style: AppTextStyles.bodyBold),
                    subtitle: Text(
                      '${entry.createdAt?.split('T').first ?? ''} • $entryTypeLabel',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}${_formatCurrency(entry.amount)}',
                          style: AppTextStyles.bodyBold.copyWith(color: amountColor),
                          textDirection: TextDirection.ltr,
                        ),
                        Text(
                          'قەرز: ${_formatCurrency(entry.balanceAfter)}',
                          style: AppTextStyles.caption,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('کێشە هەیە: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(BuildContext context, Customer customer) {
    // Note: To implement properly, a customerOrdersProvider is needed.
    // For now returning placeholder.
    return const Center(child: Text('بەمزووانە...'));
  }
}
