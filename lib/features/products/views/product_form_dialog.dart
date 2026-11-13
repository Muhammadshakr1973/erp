import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/kurdish_context_menu.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../providers/products_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/suppliers_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../admin/views/category_form_dialog.dart';
import 'barcode_generator_dialog.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final ProductModel? product;
  final int? initialSupplierId;

  const ProductFormDialog({
    super.key,
    this.product,
    this.initialSupplierId,
  });

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
  late FocusNode _unitFocusNode;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _imageUrlController;

  int? _selectedCategoryId;
  int? _selectedSupplierId;
  bool _isActive = true;
  String _dismissedSimilarityQuery = '';

  void _onNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    double currentStock = 0;
    int currentMinStock = 0;
    if (p != null) {
      num foundMin = 0;
      bool hasMin = false;
      double foundStock = 0;
      for (var s in p.stocks) {
        if (s is Map) {
          foundStock += Formatters.parseDouble(s['quantity']);
          if (s['min_stock_level'] != null) {
            foundMin += num.tryParse(s['min_stock_level']?.toString() ?? '0') ?? 0;
            hasMin = true;
          }
        }
      }
      currentStock = double.parse(foundStock.toStringAsFixed(3));
      if (hasMin) {
        currentMinStock = foundMin.toInt();
      }
    }
    _nameController = TextEditingController(text: p?.name ?? '');
    _nameController.addListener(_onNameChanged);
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _costPriceController = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(p.costPrice) : '',
    );
    _priceN1Controller = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(p.priceN1) : '',
    );
    _priceN2Controller = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(p.priceN2) : '',
    );
    _priceN3Controller = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(p.priceN3) : '',
    );
    _unitsPerCartonController = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(p.unitsPerCarton) : '12',
    );
    _unitFocusNode = FocusNode();
    _unitController = TextEditingController(
      text: (p?.unit != null && p!.unit!.isNotEmpty) ? p.unit : 'ج',
    );
    _stockController = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(currentStock) : '0',
    );
    _minStockController = TextEditingController(
      text: p != null ? Formatters.cleanNumberString(currentMinStock) : '0',
    );
    _imageUrlController = TextEditingController(text: p?.imagePath ?? '');
    _selectedCategoryId = p?.categoryId;
    _selectedSupplierId = p?.supplierId ?? widget.initialSupplierId;
    _isActive = p?.isActive ?? true;
  }

  bool _isValidImageUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _generateRandomBarcode() {
    final random = Random();
    final prefix = '604';
    final suffix = List.generate(8, (_) => random.nextInt(10)).join();
    return '$prefix$suffix';
  }

  String _normalizeForComparison(String text) {
    if (text.isEmpty) return '';
    var s = text.trim().toLowerCase();

    s = s.replaceAll('ي', 'ی');
    s = s.replaceAll('ى', 'ی');
    s = s.replaceAll('ئ', 'ی');
    s = s.replaceAll('ك', 'ک');
    s = s.replaceAll('ة', 'ە');
    s = s.replaceAll('ه', 'ە');
    s = s.replaceAll('إ', 'ا');
    s = s.replaceAll('أ', 'ا');
    s = s.replaceAll('آ', 'ا');
    s = s.replaceAll('ؤ', 'و');

    const easternDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < easternDigits.length; i++) {
      s = s.replaceAll(easternDigits[i], '$i');
    }

    s = s.replaceAll(RegExp(r'[\-_/\\()\[\]{}.,:;+*&^%$#@!~`"|]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  double _bigramSimilarity(String s1, String s2) {
    if (s1.length < 2 || s2.length < 2) return 0.0;
    final pairs1 = <String>{};
    for (int i = 0; i < s1.length - 1; i++) {
      pairs1.add(s1.substring(i, i + 2));
    }
    final pairs2 = <String>{};
    for (int i = 0; i < s2.length - 1; i++) {
      pairs2.add(s2.substring(i, i + 2));
    }
    final intersection = pairs1.intersection(pairs2).length;
    return (2.0 * intersection) / (pairs1.length + pairs2.length);
  }

  double _wordSimilarity(String w1, String w2) {
    if (w1 == w2) return 1.0;
    if (w1.length < 2 || w2.length < 2) return 0.0;
    return _bigramSimilarity(w1, w2);
  }

  double _calculateSimilarity(String query, String target) {
    final q = _normalizeForComparison(query);
    final t = _normalizeForComparison(target);

    if (q.isEmpty || t.isEmpty) return 0.0;
    if (q == t) return 1.0;

    if (t.contains(q)) return 0.90;
    if (q.contains(t) && t.length >= 3) return 0.85;

    final qTokens = q.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final tTokens = t.split(' ').where((w) => w.trim().isNotEmpty).toList();

    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    int matchedCount = 0;
    for (final qWord in qTokens) {
      bool found = false;
      for (final tWord in tTokens) {
        if (qWord == tWord) {
          found = true;
          break;
        }
        if (qWord.length >= 3 && tWord.length >= 3) {
          if (tWord.contains(qWord) || qWord.contains(tWord)) {
            found = true;
            break;
          }
        }
        if (_wordSimilarity(qWord, tWord) >= 0.75) {
          found = true;
          break;
        }
      }
      if (found) {
        matchedCount++;
      }
    }

    final tokenScore = matchedCount / qTokens.length;
    final bigramScore = _bigramSimilarity(q, t);

    return max(tokenScore, bigramScore);
  }

  List<ProductModel> _getSimilarProducts(List<ProductModel> allProducts) {
    final query = _nameController.text.trim();
    if (query.length < 2) return [];

    final List<MapEntry<ProductModel, double>> scored = [];
    for (final p in allProducts) {
      if (widget.product != null && p.id == widget.product!.id) {
        continue;
      }
      final score = _calculateSimilarity(query, p.name);
      if (score >= 0.5) {
        scored.add(MapEntry(p, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(4).map((e) => e.key).toList();
  }

  String _extractSupplierName(ProductModel p, List<SupplierModel> suppliers) {
    if (p.supplier is Map && p.supplier['name'] != null) {
      return p.supplier['name'].toString();
    }
    if (p.supplier != null && p.supplier is String && (p.supplier as String).isNotEmpty) {
      return p.supplier as String;
    }
    if (p.supplierId != null) {
      final s = suppliers.where((element) => element.id == p.supplierId).firstOrNull;
      if (s != null) return s.name;
    }
    return '';
  }

  Widget _buildSimilarityAlert(
    List<ProductModel> similarProducts,
    List<SupplierModel> suppliers,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF261E0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFBBF24),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ئاگاداری: ${similarProducts.length} کاڵای هاوشێوە دۆزرایەوە!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'بۆ ڕێگری لە تۆمارکردنی دووبارە، سەیری کاڵاکان بکە:',
                      style: AppTextStyles.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'شاردنەوە',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  setState(() {
                    _dismissedSimilarityQuery = _nameController.text.trim();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...similarProducts.map((p) {
            final supplierName = _extractSupplierName(p, suppliers);
            final stockTotal = p.totalStock;
            final unit = (p.unit != null && p.unit!.isNotEmpty) ? p.unit! : 'دانە';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.barcode.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.barcode,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (supplierName.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    supplierName,
                                    style: AppTextStyles.caption.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 13,
                                  color: stockTotal > 0 ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ستۆک: ${Formatters.cleanNumberString(stockTotal)} $unit',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: stockTotal > 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'نرخ: ${Formatters.currency(p.priceN1)}',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showExistingProductDetails(p, supplierName),
                    child: Text(
                      'وردەکاری',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showExistingProductDetails(ProductModel p, String supplierName) {
    final theme = Theme.of(context);
    final unit = (p.unit != null && p.unit!.isNotEmpty) ? p.unit! : 'دانە';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'زانیاری کاڵای هاوشێوە',
                  style: AppTextStyles.h3,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (p.barcode.isNotEmpty)
                        _detailRow('بارکۆد:', p.barcode),
                      if (p.sku != null && p.sku!.isNotEmpty)
                        _detailRow('SKU:', p.sku!),
                      if (supplierName.isNotEmpty)
                        _detailRow('کۆمپانیا:', supplierName),
                      _detailRow('کۆی ستۆک:', '${Formatters.cleanNumberString(p.totalStock)} $unit'),
                      _detailRow('کۆست:', Formatters.currency(p.costPrice)),
                      _detailRow('نرخی فرۆشتن ۱:', Formatters.currency(p.priceN1)),
                      if (p.priceN2 > 0)
                        _detailRow('نرخی فرۆشتن ۲:', Formatters.currency(p.priceN2)),
                      if (p.priceN3 > 0)
                        _detailRow('نرخی فرۆشتن ۳:', Formatters.currency(p.priceN3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              text: 'پڕکردنەوەی داتای ئەم کاڵایە لە فۆرمدا',
              type: AppButtonType.primary,
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _nameController.text = p.name;
                  _barcodeController.text = p.barcode;
                  if (p.sku != null) _skuController.text = p.sku!;
                  _costPriceController.text = Formatters.cleanNumberString(p.costPrice);
                  _priceN1Controller.text = Formatters.cleanNumberString(p.priceN1);
                  _priceN2Controller.text = Formatters.cleanNumberString(p.priceN2);
                  _priceN3Controller.text = Formatters.cleanNumberString(p.priceN3);
                  _unitsPerCartonController.text = Formatters.cleanNumberString(p.unitsPerCarton);
                  if (p.unit != null && p.unit!.isNotEmpty) {
                    _unitController.text = p.unit!;
                  }
                  if (p.supplierId != null) {
                    _selectedSupplierId = p.supplierId;
                  }
                  if (p.categoryId != null) {
                    _selectedCategoryId = p.categoryId;
                  }
                  if (p.imagePath != null && p.imagePath!.isNotEmpty) {
                    _imageUrlController.text = p.imagePath!;
                  }
                  _dismissedSimilarityQuery = p.name;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _costPriceController.dispose();
    _priceN1Controller.dispose();
    _priceN2Controller.dispose();
    _priceN3Controller.dispose();
    _unitsPerCartonController.dispose();
    _unitController.dispose();
    _unitFocusNode.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _openUnitSpinDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UnitSpinDialog(
        initialUnit: _unitController.text.trim().isEmpty
            ? 'ج'
            : _unitController.text.trim(),
        availableUnits: const [
          'ج',
          'ک',
          'پاکەت',
          'بالە',
          'عەلاگە',
          'پ',
          'دانە',
          'پارچە',
          'سێت',
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _unitController.text = result.trim();
      });
    }
  }

  Widget _buildUnitPickerField(ThemeData theme, {bool isUnified = false}) {
    final currentUnit =
        _unitController.text.trim().isEmpty ? 'ج' : _unitController.text.trim();

    return InkWell(
      onTap: _openUnitSpinDialog,
      borderRadius: isUnified ? BorderRadius.zero : BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'یەکە',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentUnit,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
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
      'unit': _unitController.text.trim().isEmpty ? 'ج' : _unitController.text.trim(),
      'category_id': _selectedCategoryId,
      'supplier_id': _selectedSupplierId,
      'is_active': _isActive ? 1 : 0,
      'initial_stock': double.tryParse(_stockController.text.trim()) ?? 0,
      'min_stock_level': int.tryParse(_minStockController.text.trim()) ?? 0,
      'image_path': _imageUrlController.text,
    };

    try {
      if (widget.product == null) {
        final newProduct =
            await ref.read(productActionsProvider).addProduct(data);
        if (mounted) {
          Navigator.pop(context, newProduct);
        }
      } else {
        final updatedProduct = await ref
            .read(productActionsProvider)
            .updateProduct(widget.product!.id, data);
        if (mounted) {
          Navigator.pop(context, updatedProduct);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    String newCategoryName = '';
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('زیادکردنی کاتیگۆری نوێ')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: TextField(
            autofocus: true,
            contextMenuBuilder: (context, editableTextState) {
              return KurdishContextMenu.build(context, editableTextState);
            },
            decoration: const InputDecoration(hintText: 'ناوی کاتیگۆری'),
            onChanged: (val) => newCategoryName = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, newCategoryName),
              child: const Text('زیادکردن'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final newCategory = await ref
            .read(categoryActionsProvider)
            .addCategory(result.trim());
        // چاوەڕێ دەکەین تا لیستەکە نوێ دەبێتەوە
        await ref.read(categoriesListProvider.future);

        if (mounted) {
          setState(() {
            _selectedCategoryId = newCategory.id;
          });
        }
      } catch (e) {
        if (mounted) {
          final message = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('کێشە لە زیادکردنی کاتیگۆری: $message')),
          );
        }
      }
    } else {
      // Reset dropdown if cancelled
      setState(() {});
    }
  }

  Future<void> _showEditCategoryDialog(CategoryModel category) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  Future<void> _showAddSupplierDialog() async {
    String newSupplierName = '';
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('زیادکردنی کۆمپانیای نوێ')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: TextField(
            autofocus: true,
            contextMenuBuilder: (context, editableTextState) {
              return KurdishContextMenu.build(context, editableTextState);
            },
            decoration: const InputDecoration(hintText: 'ناوی کۆمپانیا'),
            onChanged: (val) => newSupplierName = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, newSupplierName),
              child: const Text('زیادکردن'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final newSupplier = await ref
            .read(supplierActionsProvider)
            .addSupplier(result.trim());
        // چاوەڕێ دەکەین تا لیستەکە نوێ دەبێتەوە
        ref.invalidate(suppliersListProvider);
        await ref.read(suppliersListProvider.future);

        if (mounted) {
          setState(() {
            _selectedSupplierId = newSupplier.id;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('کێشە لە زیادکردنی کۆمپانیا: $e')),
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
    final allProducts = ref.watch(productsListProvider).valueOrNull ?? [];
    final suppliers = suppliersAsync.valueOrNull ?? [];
    final currentNameQuery = _nameController.text.trim();
    final similarProducts = _dismissedSimilarityQuery == currentNameQuery
        ? <ProductModel>[]
        : _getSimilarProducts(allProducts);
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: MediaQuery.of(context).viewInsets.copyWith(bottom: 0),
      ),
      child: Dialog(
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
                      widget.product == null
                          ? 'زیادکردنی کاڵا'
                          : 'دەستکاریکردنی کاڵا',
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
                                labelText: 'لینکی وێنە',
                                hintText: 'https://...',
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
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imageUrlController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Basic Info
                        if (isMobile) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _nameController,
                                  labelText: 'ناوی کاڵا',
                                  hintText: 'ناوی کاڵا',
                                  validator: (v) =>
                                      v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Switch(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                            ],
                          ),
                          if (similarProducts.isNotEmpty) ...[
                            _buildSimilarityAlert(similarProducts, suppliers, theme),
                          ] else ...[
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(
                              children: [
                                // Right input (first child in RTL: Barcode col-8)
                                Expanded(
                                  flex: 8,
                                  child: AppTextField(
                                    controller: _barcodeController,
                                    labelText: 'بارکۆد',
                                    hintText: 'بارکۆد',
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(24),
                                      bottomRight: Radius.circular(24),
                                      topLeft: Radius.zero,
                                      bottomLeft: Radius.zero,
                                    ),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 19),
                                          tooltip: 'سکانکردنی بارکۆد بە کامێرا',
                                          onPressed: () {
                                            CameraBarcodeScanner.show(
                                              context,
                                              (scanned) {
                                                setState(() {
                                                  _barcodeController.text = scanned;
                                                });
                                              },
                                              closeOnScan: true,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 20),
                                          tooltip: 'دروستکردنی بارکۆدی ئۆتۆماتیکی',
                                          onPressed: () {
                                            setState(() {
                                              _barcodeController.text = _generateRandomBarcode();
                                            });
                                          },
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 19),
                                          tooltip: 'پرێنتکردن و داگرتنی بارکۆد',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => BarcodeGeneratorDialog(
                                                product: widget.product,
                                                initialBarcode: _barcodeController.text,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                // Left input (second child in RTL: SKU col-4)
                                Expanded(
                                  flex: 4,
                                  child: AppTextField(
                                    controller: _skuController,
                                    labelText: 'SKU',
                                    hintText: 'SKU',
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      bottomLeft: Radius.circular(24),
                                      topRight: Radius.zero,
                                      bottomRight: Radius.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: _nameController,
                                  labelText: 'ناوی کاڵا',
                                  hintText: 'ناوی کاڵا',
                                  validator: (v) =>
                                      v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 8,
                                child: AppTextField(
                                  controller: _barcodeController,
                                  labelText: 'بارکۆد',
                                  hintText: 'بارکۆد',
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 19),
                                        tooltip: 'سکانکردنی بارکۆد بە کامێرا',
                                        onPressed: () {
                                          CameraBarcodeScanner.show(
                                            context,
                                            (scanned) {
                                              setState(() {
                                                _barcodeController.text = scanned;
                                              });
                                            },
                                            closeOnScan: true,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        icon: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 20),
                                        tooltip: 'دروستکردنی بارکۆدی ئۆتۆماتیکی',
                                        onPressed: () {
                                          setState(() {
                                            _barcodeController.text = _generateRandomBarcode();
                                          });
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 19),
                                        tooltip: 'پرێنتکردن و داگرتنی بارکۆد',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => BarcodeGeneratorDialog(
                                              product: widget.product,
                                              initialBarcode: _barcodeController.text,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 4,
                                child: AppTextField(
                                  controller: _skuController,
                                  labelText: 'SKU',
                                  hintText: 'SKU',
                                ),
                              ),
                            ],
                          ),
                          if (similarProducts.isNotEmpty) ...[
                            _buildSimilarityAlert(similarProducts, suppliers, theme),
                          ] else ...[
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.4,
                              ),
                              width: 1,
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                // Category Selector
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: categoriesAsync.when(
                                      data: (categories) {
                                        final int? validValue =
                                            categories.any(
                                              (c) =>
                                                  c.id == _selectedCategoryId,
                                            )
                                            ? _selectedCategoryId
                                            : null;
                                          return DropdownButtonHideUnderline(
                                            child: DropdownButtonFormField<int>(
                                              initialValue: validValue,
                                              isExpanded: true,
                                              hint: const Text('جۆر هەڵبژێرە'),
                                              decoration: const InputDecoration(
                                                labelText: 'جۆری کاڵا',
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              selectedItemBuilder: (context) {
                                                return [
                                                  ...categories.map(
                                                    (c) => Align(
                                                      alignment:
                                                          AlignmentDirectional
                                                              .centerStart,
                                                      child: Text(
                                                        c.name,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerStart,
                                                    child: Text(
                                                      '+ زیادکردنی نوێ',
                                                      style: TextStyle(
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ];
                                              },
                                              items: [
                                                ...categories.map(
                                                  (c) => DropdownMenuItem<int>(
                                                    value: c.id,
                                                    child: Builder(
                                                      builder: (menuContext) {
                                                        return GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onLongPress: () {
                                                            final dialogRoute =
                                                                ModalRoute.of(
                                                                  context,
                                                                );
                                                            final menuRoute =
                                                                ModalRoute.of(
                                                                  menuContext,
                                                                );
                                                            if (menuRoute !=
                                                                    null &&
                                                                menuRoute !=
                                                                    dialogRoute &&
                                                                menuRoute
                                                                    .isActive) {
                                                              Navigator.of(
                                                                menuContext,
                                                              ).pop();
                                                            }
                                                            Future.microtask(
                                                              () {
                                                                if (mounted) {
                                                                  _showEditCategoryDialog(
                                                                    c,
                                                                  );
                                                                }
                                                              },
                                                            );
                                                          },
                                                          child: Container(
                                                            width:
                                                                double.infinity,
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minHeight:
                                                                      kMinInteractiveDimension,
                                                                ),
                                                            alignment:
                                                                AlignmentDirectional
                                                                    .centerStart,
                                                            child: Text(
                                                              c.name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: -1,
                                                  child: Text(
                                                    '+ زیادکردنی نوێ',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            onChanged: (v) {
                                              if (v == -1) {
                                                _showAddCategoryDialog();
                                              } else {
                                                setState(
                                                  () => _selectedCategoryId = v,
                                                );
                                              }
                                            },
                                          ),
                                        );
                                      },
                                      loading: () => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      error: (err, stack) =>
                                          const Text('کێشە لە جۆرەکان'),
                                    ),
                                  ),
                                ),
                                // 1px Vertical Divider
                                VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                // Supplier Selector
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: suppliersAsync.when(
                                      data: (suppliers) {
                                        final int? validValue =
                                            suppliers.any(
                                              (s) =>
                                                  s.id == _selectedSupplierId,
                                            )
                                            ? _selectedSupplierId
                                            : null;
                                        return DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField<int>(
                                            initialValue: validValue,
                                            isExpanded: true,
                                            hint: const Text(
                                              'کۆمپانیا هەڵبژێرە',
                                            ),
                                            decoration: const InputDecoration(
                                              labelText: 'کۆمپانیا',
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            items: [
                                              ...suppliers.map(
                                                (s) => DropdownMenuItem(
                                                  value: s.id,
                                                  child: Text(
                                                    s.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: -1,
                                                child: Text(
                                                  '+ زیادکردنی نوێ',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v == -1) {
                                                _showAddSupplierDialog();
                                              } else {
                                                setState(
                                                  () => _selectedSupplierId = v,
                                                );
                                              }
                                            },
                                          ),
                                        );
                                      },
                                      loading: () => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      error: (err, stack) =>
                                          const Text('کێشە لە کۆمپانیاکان'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Prices Unified Cohesive Group
                        if (isMobile)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // First row: Cost and Price N1
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _costPriceController,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'کۆست',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'کۆست',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.4),
                                      ),
                                      Expanded(
                                        child: AppTextField(
                                          controller: _priceN1Controller,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'نرخی ١',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'N1',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                // Second row: Price N2 and Price N3
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _priceN2Controller,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'نرخی ٢',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'N2',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.4),
                                      ),
                                      Expanded(
                                        child: AppTextField(
                                          controller: _priceN3Controller,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'نرخی ٣',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'N3',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1,
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Cost Price
                                  Expanded(
                                    child: AppTextField(
                                      controller: _costPriceController,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'کۆست',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'کۆست',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Price N1
                                  Expanded(
                                    child: AppTextField(
                                      controller: _priceN1Controller,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'نرخی ١',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'N1',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Price N2
                                  Expanded(
                                    child: AppTextField(
                                      controller: _priceN2Controller,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'نرخی ٢',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'N2',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Price N3
                                  Expanded(
                                    child: AppTextField(
                                      controller: _priceN3Controller,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'نرخی ٣',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'N3',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),

                        // Quantities & Stock Unified Cohesive Group
                        if (isMobile)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // First row: Carton and Unit
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _unitsPerCartonController,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'کارتۆن',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'کارتۆن',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.4),
                                      ),
                                      Expanded(
                                        child: _buildUnitPickerField(
                                          theme,
                                          isUnified: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                // Second row: Stock and Min Stock
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _stockController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          customDecoration: InputDecoration(
                                            labelText: 'ستۆک',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'ستۆک',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.4),
                                      ),
                                      Expanded(
                                        child: AppTextField(
                                          controller: _minStockController,
                                          keyboardType: TextInputType.number,
                                          customDecoration: InputDecoration(
                                            labelText: 'کەمترین بڕ',
                                            labelStyle: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            hintText: 'ئاستی ئاگادارکردنەوە',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1,
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Carton
                                  Expanded(
                                    child: AppTextField(
                                      controller: _unitsPerCartonController,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'کارتۆن',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'کارتۆن',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Unit
                                  Expanded(
                                    child: _buildUnitPickerField(
                                      theme,
                                      isUnified: true,
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Stock
                                  Expanded(
                                    child: AppTextField(
                                      controller: _stockController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      customDecoration: InputDecoration(
                                        labelText: 'ستۆک',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'ستۆک',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  // Min Stock
                                  Expanded(
                                    child: AppTextField(
                                      controller: _minStockController,
                                      keyboardType: TextInputType.number,
                                      customDecoration: InputDecoration(
                                        labelText: 'کەمترین بڕ',
                                        labelStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        hintText: 'ئاستی ئاگادارکردنەوە',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!isMobile) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              const SizedBox(width: AppSpacing.xs),
                              Text('چالاکە', style: AppTextStyles.bodyBold),
                              const SizedBox(width: AppSpacing.sm),
                              Switch(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: keyboardHeight),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: isMobile ? 120 : 140,
                  child: AppButton(
                    text: 'پاشەکەوت',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _UnitSpinDialog extends StatefulWidget {
  final String initialUnit;
  final List<String> availableUnits;

  const _UnitSpinDialog({
    required this.initialUnit,
    required this.availableUnits,
  });

  @override
  State<_UnitSpinDialog> createState() => _UnitSpinDialogState();
}

class _UnitSpinDialogState extends State<_UnitSpinDialog> {
  late List<String> _units;
  late int _selectedIndex;
  late FixedExtentScrollController _scrollController;
  final TextEditingController _customUnitController = TextEditingController();
  final FocusNode _customUnitFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _units = List<String>.from(widget.availableUnits);
    final initial = widget.initialUnit.trim();
    if (initial.isNotEmpty && !_units.contains(initial)) {
      _units.insert(0, initial);
    }
    _selectedIndex = _units.indexOf(initial);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
    _scrollController = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customUnitController.dispose();
    _customUnitFocus.dispose();
    super.dispose();
  }

  void _addCustomUnit() {
    final text = _customUnitController.text.trim();
    if (text.isEmpty) return;

    final existingIndex = _units.indexOf(text);
    if (existingIndex >= 0) {
      setState(() {
        _selectedIndex = existingIndex;
      });
      _scrollController.animateToItem(
        existingIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      setState(() {
        _units.insert(0, text);
        _selectedIndex = 0;
      });
      _scrollController.jumpToItem(0);
    }
    _customUnitController.clear();
    _customUnitFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with top-left close button (in RTL, close button is at the left)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'دیاریکردنی یەکە',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'داخستن',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Top input for custom unit
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customUnitController,
                      focusNode: _customUnitFocus,
                      contextMenuBuilder: (context, editableTextState) {
                        return KurdishContextMenu.build(context, editableTextState);
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomUnit(),
                      decoration: InputDecoration(
                        hintText: 'دانانی یەکەی تر ئەگەر لەم لیستەدا نییە...',
                        hintStyle: AppTextStyles.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    text: 'زیادکردن',
                    icon: Icons.add,
                    type: AppButtonType.secondary,
                    onPressed: _addCustomUnit,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Helper caption
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swipe_vertical_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'سپینەکە بەرز و نزم بکە بۆ دیاریکردنی یەکە',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vertical Spin Wheel
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Selection highlight bar in the center
                      Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                      ),

                      // List wheel scroll view
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: ListWheelScrollView.useDelegate(
                          controller: _scrollController,
                          itemExtent: 48.0,
                          perspective: 0.003,
                          diameterRatio: 1.5,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _units.length,
                            builder: (context, index) {
                              final isSelected = index == _selectedIndex;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _scrollController.animateToItem(
                                    index,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 150),
                                    style: TextStyle(
                                      fontSize: isSelected ? 21 : 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                      fontFamily: isSelected ? 'rudawbold' : 'rudawregular2',
                                    ),
                                    child: Text(_units[index]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Gradient fade on top
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 52,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.surface,
                                  theme.colorScheme.surface.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Gradient fade on bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 52,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  theme.colorScheme.surface,
                                  theme.colorScheme.surface.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Confirmation button (strictly primary action, no cancel at bottom)
              AppButton(
                text: 'تەئکیدکردنەوە',
                type: AppButtonType.primary,
                onPressed: () {
                  final customText = _customUnitController.text.trim();
                  if (customText.isNotEmpty) {
                    Navigator.pop(context, customText);
                  } else if (_selectedIndex >= 0 && _selectedIndex < _units.length) {
                    Navigator.pop(context, _units[_selectedIndex]);
                  } else {
                    Navigator.pop(context, 'ج');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
