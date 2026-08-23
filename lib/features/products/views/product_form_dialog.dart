import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/product_model.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _costPriceController;
  late TextEditingController _priceN1Controller;
  late TextEditingController _priceN2Controller;
  late TextEditingController _priceN3Controller;
  late TextEditingController _unitsPerCartonController;
  late TextEditingController _unitController;
  
  int? _selectedCategoryId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _costPriceController = TextEditingController(text: p?.costPrice.toString() ?? '');
    _priceN1Controller = TextEditingController(text: p?.priceN1.toString() ?? '');
    _priceN2Controller = TextEditingController(text: p?.priceN2.toString() ?? '');
    _priceN3Controller = TextEditingController(text: p?.priceN3.toString() ?? '');
    _unitsPerCartonController = TextEditingController(text: p?.unitsPerCarton.toString() ?? '1');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _selectedCategoryId = p?.categoryId;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _costPriceController.dispose();
    _priceN1Controller.dispose();
    _priceN2Controller.dispose();
    _priceN3Controller.dispose();
    _unitsPerCartonController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text,
      'barcode': _barcodeController.text,
      'sku': _skuController.text,
      'cost_price': double.tryParse(_costPriceController.text) ?? 0,
      'price_n1': double.tryParse(_priceN1Controller.text) ?? 0,
      'price_n2': double.tryParse(_priceN2Controller.text) ?? 0,
      'price_n3': double.tryParse(_priceN3Controller.text) ?? 0,
      'units_per_carton': int.tryParse(_unitsPerCartonController.text) ?? 1,
      'unit': _unitController.text,
      'category_id': _selectedCategoryId,
      'is_active': _isActive ? 1 : 0,
    };

    try {
      if (widget.product == null) {
        await ref.read(productActionsProvider).addProduct(data);
      } else {
        await ref.read(productActionsProvider).updateProduct(widget.product!.id, data);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product == null ? 'زیادکردنی کاڵا' : 'دەستکاریکردنی کاڵا',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _nameController,
                        hintText: 'ناوی کاڵا',
                        validator: (v) => v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _barcodeController,
                              hintText: 'بارکۆد',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _skuController,
                              hintText: 'SKU کۆدی ناوخۆیی',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      categoriesAsync.when(
                        data: (categories) => DropdownButtonFormField<int>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: 'جۆری کاڵا (Category)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) => const Text('کێشە لە هێنانی جۆرەکان'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _unitsPerCartonController,
                              hintText: 'دانە لە کارتۆندا',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _unitController,
                              hintText: 'یەکە (دانە، کیلۆ...)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _costPriceController,
                              hintText: 'نرخی کڕین',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _priceN1Controller,
                              hintText: 'نرخی فرۆشتن 1',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _priceN2Controller,
                              hintText: 'نرخی فرۆشتن 2',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _priceN3Controller,
                              hintText: 'نرخی فرۆشتن 3',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        title: const Text('چالاكە'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('پاشگەزبوونەوە'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    text: 'پاشەکەوتکردن',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
