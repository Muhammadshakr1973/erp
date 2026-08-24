import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/product_model.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/suppliers_provider.dart';

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
  late TextEditingController _stockController;
  late TextEditingController _imageUrlController;

  int? _selectedCategoryId;
  int? _selectedSupplierId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    int currentStock = 0;
    if (p != null) {
      for (var s in p.stocks) {
        currentStock += (s['quantity'] as int?) ?? 0;
      }
    }
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _costPriceController = TextEditingController(text: p != null ? p.costPrice.toString() : '');
    _priceN1Controller = TextEditingController(text: p != null ? p.priceN1.toString() : '');
    _priceN2Controller = TextEditingController(text: p != null ? p.priceN2.toString() : '');
    _priceN3Controller = TextEditingController(text: p != null ? p.priceN3.toString() : '');
    _unitsPerCartonController = TextEditingController(text: p?.unitsPerCarton.toString() ?? '12');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _stockController = TextEditingController(text: p != null ? currentStock.toString() : '0');
    _imageUrlController = TextEditingController(text: p?.imagePath ?? '');
    _selectedCategoryId = p?.categoryId;
    _selectedSupplierId = p?.supplierId;
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
    _stockController.dispose();
    _imageUrlController.dispose();
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
      'units_per_carton': int.tryParse(_unitsPerCartonController.text) ?? 12,
      'unit': _unitController.text,
      'category_id': _selectedCategoryId,
      'supplier_id': _selectedSupplierId,
      'is_active': _isActive ? 1 : 0,
      'initial_stock': int.tryParse(_stockController.text) ?? 0,
      'image_path': _imageUrlController.text,
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
  
  Future<void> _showAddCategoryDialog() async {
    String newCategoryName = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('زیادکردنی کاتیگۆری نوێ'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'ناوی کاتیگۆری'),
            onChanged: (val) => newCategoryName = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('پاشگەزبوونەوە'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, newCategoryName),
              child: const Text('زیادکردن'),
            ),
          ],
        );
      }
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final newCategory = await ref.read(categoryActionsProvider).addCategory(result.trim());
        setState(() {
          _selectedCategoryId = newCategory.id;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('کێشە لە زیادکردنی کاتیگۆری: $e')),
          );
        }
      }
    } else {
      // Reset dropdown if cancelled
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: isMobile ? double.infinity : 900,
        height: screenHeight * 0.9,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.product == null ? 'زیادکردنی کاڵا' : 'دەستکاریکردنی کاڵا',
                      style: AppTextStyles.h2,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _unitsPerCartonController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _unitController,
                            labelText: 'یەکە (دانە، کیلۆ...)',
                            hintText: 'دانە، کیلۆ',
                                  labelText: 'دانە لە کارتۆندا',
                                  hintText: 'ژمارەی دانەکان',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _unitController,
                                  labelText: 'یەکە (دانە، کیلۆ...)',
                                  hintText: 'دانە، کیلۆ',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _stockController,
                                  labelText: 'مەوجودکراو (Stock)',
                                  hintText: 'بڕی عەدەدی کۆگا',

                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
