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

  bool _isValidImageUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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
        // چاوەڕێ دەکەین تا لیستەکە نوێ دەبێتەوە
        await ref.read(categoriesListProvider.future);
        
        if (mounted) {
          setState(() {
            _selectedCategoryId = newCategory.id;
          });
        }
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        // Image URL and Preview
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _imageUrlController,
                                labelText: 'لینکی وێنەی کاڵا',
                                hintText: 'لینک لێرە دابنێ (بۆ نموونە https://...)',
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                            if (_isValidImageUrl(_imageUrlController.text)) ...[
                              const SizedBox(width: AppSpacing.md),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imageUrlController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Basic Info
                        if (isMobile) ...[
                          AppTextField(
                            controller: _nameController,
                            labelText: 'ناوی کاڵا',
                            hintText: 'ناوی کاڵا بنووسە',
                            validator: (v) => v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _barcodeController,
                            labelText: 'بارکۆد',
                            hintText: 'بارکۆد لێرە بنووسە',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: () {
                                CameraBarcodeScanner.show(context, (scanned) {
                                  setState(() {
                                    _barcodeController.text = scanned;
                                  });
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _skuController,
                            labelText: 'SKU کۆدی ناوخۆیی',
                            hintText: 'کۆدی ناوخۆیی بنووسە',
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: _nameController,
                                  labelText: 'ناوی کاڵا',
                                  hintText: 'ناوی کاڵا بنووسە',
                                  validator: (v) => v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 1,
                                child: AppTextField(
                                  controller: _barcodeController,
                                  labelText: 'بارکۆد',
                                  hintText: 'بارکۆد',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    onPressed: () {
                                      CameraBarcodeScanner.show(context, (scanned) {
                                        setState(() {
                                          _barcodeController.text = scanned;
                                        });
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 1,
                                child: AppTextField(
                                  controller: _skuController,
                                  labelText: 'SKU کۆد',
                                  hintText: 'کۆدی ناوخۆیی',
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        // Dropdowns
                        Builder(
                          builder: (context) {
                            Widget categoryDropdown = categoriesAsync.when(
                              data: (categories) {
                                final int? validValue = categories.any((c) => c.id == _selectedCategoryId)
                                    ? _selectedCategoryId
                                    : null;
                                return DropdownButtonFormField<int>(
                                  value: validValue,
                                  decoration: InputDecoration(
                                    labelText: 'جۆری کاڵا (Category)',
                                    labelStyle: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                                  ),
                                  items: [
                                    ...categories.map((c) {
                                      return DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      );
                                    }),
                                    const DropdownMenuItem(
                                      value: -1,
                                      child: Text('+ زیادکردنی کاتیگۆری نوێ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                  onChanged: (v) {
                                    if (v == -1) {
                                      _showAddCategoryDialog();
                                    } else {
                                      setState(() => _selectedCategoryId = v);
                                    }
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, stack) => const Text('کێشە لە هێنانی جۆرەکان'),
                            );

                            Widget supplierDropdown = suppliersAsync.when(
                              data: (suppliers) {
                                final int? validValue = suppliers.any((s) => s.id == _selectedSupplierId)
                                    ? _selectedSupplierId
                                    : null;
                                return DropdownButtonFormField<int>(
                                  value: validValue,
                                  decoration: InputDecoration(
                                    labelText: 'سەپڵایەر (Supplier)',
                                    labelStyle: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                                  ),
                                  items: suppliers.map((s) {
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedSupplierId = v),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, stack) => const Text('کێشە لە هێنانی سەپڵایەرەکان'),
                            );

                            if (isMobile) {
                              return Column(
                                children: [
                                  categoryDropdown,
                                  const SizedBox(height: AppSpacing.md),
                                  supplierDropdown,
                                ],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(child: categoryDropdown),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: supplierDropdown),
                                ],
                              );
                            }
                          }
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Prices
                        if (isMobile) ...[
                          AppTextField(
                            controller: _costPriceController,
                            labelText: 'نرخی کڕین',
                            hintText: 'بڕی نرخ بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _priceN1Controller,
                            labelText: 'نرخی فرۆشتن 1',
                            hintText: 'بڕی نرخ بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _priceN2Controller,
                            labelText: 'نرخی فرۆشتن 2',
                            hintText: 'بڕی نرخ بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _priceN3Controller,
                            labelText: 'نرخی فرۆشتن 3',
                            hintText: 'بڕی نرخ بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _costPriceController,
                                  labelText: 'نرخی کڕین',
                                  hintText: 'بڕی نرخ بنووسە',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _priceN1Controller,
                                  labelText: 'نرخی فرۆشتن 1',
                                  hintText: 'بڕی نرخ',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _priceN2Controller,
                                  labelText: 'نرخی فرۆشتن 2',
                                  hintText: 'بڕی نرخ',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  controller: _priceN3Controller,
                                  labelText: 'نرخی فرۆشتن 3',
                                  hintText: 'بڕی نرخ',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: AppSpacing.md),

                        // Quantities & Status
                        if (isMobile) ...[
                          AppTextField(
                            controller: _unitsPerCartonController,
                            labelText: 'دانە لە کارتۆندا',
                            hintText: 'ژمارەی دانەکان بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _unitController,
                            labelText: 'یەکە (دانە، کیلۆ...)',
                            hintText: 'دانە، کیلۆ یان کارتۆن',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _stockController,
                            labelText: 'مەوجودکراو / کۆگا (Stock Quantity)',
                            hintText: 'بڕی عەدەدی کۆگا بنووسە',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                            title: const Text('چالاكە'),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _unitsPerCartonController,
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
                              Expanded(
                                child: SwitchListTile(
                                  title: const Text('چالاكە'),
                                  value: _isActive,
                                  onChanged: (v) => setState(() => _isActive = v),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                        ],

                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('پاشگەزبوونەوە'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: isMobile ? 120 : 140,
                      child: AppButton(
                        text: 'پاشەکەوتکردن',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
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
