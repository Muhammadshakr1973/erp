import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _phone2Controller;
  late TextEditingController _addressController;
  late TextEditingController _initialDebtController;
  String _priceType = 'N2';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name);
    _phoneController = TextEditingController(text: widget.customer?.phone);
    _phone2Controller = TextEditingController(text: widget.customer?.phone2);
    _addressController = TextEditingController(text: widget.customer?.address);
    _initialDebtController = TextEditingController();
    _priceType = widget.customer?.priceType ?? 'N2';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _initialDebtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(customerActionsProvider);
      if (widget.customer == null) {
        final initialDebt = int.tryParse(_initialDebtController.text.trim());
        await actions.addCustomer(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          priceType: _priceType,
          initialDebt: initialDebt,
        );
      } else {
        await actions.updateCustomer(
          widget.customer!.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          priceType: _priceType,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null ? 'کڕیار بەسەرکەوتوویی زیادکرا' : 'زانیاری کڕیار نوێکرایەوە'),
            backgroundColor: AppColors.success,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: isMobile ? double.infinity : 520,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.customer == null ? 'زیادکردنی کڕیاری نوێ' : 'دەستکاریکردنی کڕیار',
                      style: AppTextStyles.h2,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _nameController,
                          labelText: 'ناوی کڕیار / مارکێت',
                          hintText: 'نموونە: مارکێتی بێستون',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'تکایە ناوی کڕیار بنووسە';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _phoneController,
                                labelText: 'ژمارەی مۆبایل',
                                hintText: '0750 ...',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: _phone2Controller,
                                labelText: 'ژمارەی دووەم (ئارەزوومەندانە)',
                                hintText: '0770 ...',
                                prefixIcon: Icons.phone_android_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _addressController,
                          labelText: 'ناونیشان / شوێن',
                          hintText: 'هەولێر، گەڕەکی ڕزگاری...',
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _priceType,
                          decoration: const InputDecoration(
                            labelText: 'جۆری نرخ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'N1', child: Text('نرخی یەکەم (N1 - تاک)')),
                            DropdownMenuItem(value: 'N2', child: Text('نرخی دووەم (N2 - کۆ)')),
                            DropdownMenuItem(value: 'N3', child: Text('نرخی سێیەم (N3 - تایبەت)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _priceType = val);
                          },
                        ),
                        if (widget.customer == null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _initialDebtController,
                            labelText: 'قەرزی پێشینە / قەرزی سەرەتا (د.ع)',
                            hintText: '0',
                            prefixIcon: Icons.account_balance_wallet_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
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
                      child: const Text('پاشگەزبوونەوە'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
