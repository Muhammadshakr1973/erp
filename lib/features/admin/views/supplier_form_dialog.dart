import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/suppliers_provider.dart';
import 'providers/reports_provider.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPaying = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _contactPersonController;
  late TextEditingController _initialDebtController;

  late TextEditingController _paymentAmountController;
  late TextEditingController _paymentNotesController;

  String? _ledgerEntryType;
  DateTime? _ledgerStartDate;
  DateTime? _ledgerEndDate;
  Map<String, dynamic> _ledgerFilters = {};

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _ledgerFilters = {'supplier_id': widget.supplier!.id.toString()};
    }
    _nameController = TextEditingController(text: widget.supplier?.name);
    _phoneController = TextEditingController(text: widget.supplier?.phone);
    _addressController = TextEditingController(text: widget.supplier?.address);
    _contactPersonController = TextEditingController(text: widget.supplier?.contactPerson);
    _initialDebtController = TextEditingController();

    _paymentAmountController = TextEditingController();
    _paymentNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _initialDebtController.dispose();
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(supplierActionsProvider);
      if (widget.supplier == null) {
        final initialDebt = int.tryParse(_initialDebtController.text.trim());
        await actions.addSupplier(
          _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
          initialDebt: initialDebt,
        );
      } else {
        await actions.updateSupplier(
          widget.supplier!.id,
          _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کێشە لە پاشەکەوتکردن: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_paymentFormKey.currentState!.validate()) return;

    final amountText = _paymentAmountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە بڕێکی دروست بنووسە')),
      );
      return;
    }

    setState(() => _isPaying = true);

    try {
      final actions = ref.read(supplierActionsProvider);
      await actions.paySupplier(
        widget.supplier!.id,
        amount,
        notes: _paymentNotesController.text.trim().isEmpty ? null : _paymentNotesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قەرزەکە بە سەرکەوتوویی کەمکرایەوە')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کێشە لە نوێکردنەوەی قەرز: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final childWidget = widget.supplier == null
        ? _buildProfileForm(context)
        : DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('بەڕێوەبردنی کۆمپانیا', style: AppTextStyles.h2),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TabBar(
                  tabs: const [
                    Tab(text: 'زانیاری'),
                    Tab(text: 'پارەدان'),
                    Tab(text: 'مێژوو'),
                  ],
                  labelStyle: AppTextStyles.bodyBold,
                  unselectedLabelStyle: AppTextStyles.bodyMedium,
                  labelColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: _buildProfileFormFields(context)),
                        SingleChildScrollView(child: _buildDebtForm(context)),
                        _buildLedgerHistory(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: isMobile ? double.infinity : 500,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: childWidget,
        ),
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('زیادکردنی کۆمپانیا', style: AppTextStyles.h2),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: _buildProfileFormFields(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 140,
                child: AppButton(
                  text: 'پاشەکەوت',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('داخستن'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFormFields(BuildContext context) {
    return Form(
      key: widget.supplier == null ? null : _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            labelText: 'ناوی کۆمپانیا',
            hintText: 'کۆمپانیای ...',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'تکایە ناوی کۆمپانیا بنووسە';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _phoneController,
            labelText: 'ژمارەی مۆبایل',
            hintText: '0750 ...',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _addressController,
            labelText: 'ناونیشان',
            hintText: 'هەولێر، سلێمانی، ...',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _contactPersonController,
            labelText: 'کەسی پەیوەندیدار',
            hintText: 'ناوى بەرپرس یان پەیوەندی ...',
          ),
          if (widget.supplier == null) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _initialDebtController,
              labelText: 'قەرزی سەرەتا (بە دینار)',
              hintText: '0',
              keyboardType: TextInputType.number,
            ),
          ],
          if (widget.supplier != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'پاشەکەوتکردنی گۆڕانکارییەکان',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtForm(BuildContext context) {
    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: Column(
              children: [
                const Text('بڕی قەرزی ئێستای کۆمپانیا', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(widget.supplier?.debt ?? 0),
                  style: AppTextStyles.priceLarge.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('دانەوەی بەشێک لە قەرز', style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _paymentAmountController,
            labelText: 'بڕی پارە',
            hintText: 'نموونە: 150000',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'تکایە بڕی پارەی دراو بنووسە';
              }
              if (int.tryParse(value) == null) {
                return 'تکایە تەنها ژمارە بنووسە';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _paymentNotesController,
            labelText: 'تێبینی پارەدان',
            hintText: 'تێبینی بنووسە لێرە ...',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'تۆمارکردنی پارەدان',
            isLoading: _isPaying,
            onPressed: _submitPayment,
          ),
        ],
      ),
    );
  }

  void _applyLedgerFilters() {
    setState(() {
      _ledgerFilters = {
        'supplier_id': widget.supplier!.id.toString(),
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
      _ledgerFilters = {'supplier_id': widget.supplier!.id.toString()};
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

  Widget _buildLedgerHistory(BuildContext context) {
    if (widget.supplier == null) return const SizedBox.shrink();
    
    final ledgerAsync = ref.watch(supplierDebtsReportProvider(_ledgerFilters));
    
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // Filter UI
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                        DropdownMenuItem(value: 'PURCHASE', child: Text('کڕین')),
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
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ledgerAsync.when(
            data: (ledgerList) {
              if (ledgerList.isEmpty) {
                return const Center(child: Text('هیچ مێژوویەک نییە'));
              }
              return ListView.separated(
                itemCount: ledgerList.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = ledgerList[index];
                  final isCredit = entry.type == 'credit';
                  final amountColor = isCredit ? AppColors.success : AppColors.danger;
                  
                  return ListTile(
                    title: Text(entry.description ?? 'بێ تێبینی', style: AppTextStyles.bodyBold),
                    subtitle: Text(
                      '${entry.createdAt?.split('T').first ?? ''} • ${entry.entryType}',
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
}
