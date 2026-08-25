import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/suppliers_provider.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _contactPersonController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name);
    _phoneController = TextEditingController(text: widget.supplier?.phone);
    _addressController = TextEditingController(text: widget.supplier?.address);
    _contactPersonController = TextEditingController(text: widget.supplier?.contactPerson);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(supplierActionsProvider);
      if (widget.supplier == null) {
        await actions.addSupplier(
          _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
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
        width: isMobile ? double.infinity : 500,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.supplier == null
                          ? 'زیادکردنی کۆمپانیا'
                          : 'دەستکاریکردنی کۆمپانیا',
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
                      child: const Text('داخستن'),
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
