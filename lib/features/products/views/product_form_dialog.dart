import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/global_numeric_keyboard.dart';
import '../../../core/components/numeric_keyboard_manager.dart';
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
import '../utils/category_similarity.dart';
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
  final _categoryFieldKey = GlobalKey<FormFieldState<int>>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _costPriceController;
  late TextEditingController _priceN1Controller;
  late TextEditingController _priceN2Controller;
  late TextEditingController _priceN3Controller;
  late TextEditingController _unitsPerCartonController;
  late FocusNode _unitsPerCartonFocusNode;
  late TextEditingController _unitController;
  late FocusNode _unitFocusNode;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _imageUrlController;

  int? _selectedCategoryId;
  int? _selectedSupplierId;
  bool _isActive = true;
  String _dismissedSimilarityQuery = '';

  bool _isParentMode = false;
  bool _isEditingVariant = false;
  late TextEditingController _variantNameController;
  bool _variantUseParentPrice = true;
  final List<_VariantDraftRow> _variants = [];
  final List<int> _detachedVariantIds = [];

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
    _unitsPerCartonFocusNode = FocusNode();
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

    _isParentMode = p?.isParent ?? false;
    _isEditingVariant = p?.isVariant ?? false;
    _variantNameController = TextEditingController(
      text: p != null && p.isVariant ? p.displayVariantLabel : '',
    );
    _variantUseParentPrice = p?.useParentPrice ?? true;

    if (p != null && p.isParent) {
      final allProducts = ref.read(productsListProvider).valueOrNull ?? [];
      final existingChildren = allProducts.where((c) => c.parentId == p.id).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      for (final child in existingChildren) {
        _variants.add(_VariantDraftRow.fromProduct(child));
      }
    }
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
    _variantNameController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    _barcodeController.dispose();
    _skuController.dispose();
    _costPriceController.dispose();
    _priceN1Controller.dispose();
    _priceN2Controller.dispose();
    _priceN3Controller.dispose();
    try {
      final keyboardNotifier = ref.read(numericKeyboardProvider.notifier);
      final keyboardState = ref.read(numericKeyboardProvider);
      if (keyboardState.controller == _unitsPerCartonController) {
        keyboardNotifier.hideKeyboardOnly();
      }
    } catch (_) {}
    _unitsPerCartonController.dispose();
    _unitsPerCartonFocusNode.dispose();
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

  void _openUnitsPerCartonKeyboard(String currentUnit) {
    final rawText = _unitsPerCartonController.text;
    final cleaned = Formatters.cleanNumberString(rawText);
    if (cleaned != rawText &&
        (rawText.endsWith('.0') ||
            rawText.endsWith('.00') ||
            rawText.endsWith('.000'))) {
      _unitsPerCartonController.text = cleaned;
    }

    ref.read(numericKeyboardProvider.notifier).register(
          controller: _unitsPerCartonController,
          focusNode: _unitsPerCartonFocusNode,
          decimal: false,
          signed: false,
        );

    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return NumericKeyboardDialog(
          controller: _unitsPerCartonController,
          labelText: '$currentUnit دانە',
          hintText: '12',
        );
      },
    ).then((_) {
      if (mounted) {
        _unitsPerCartonFocusNode.unfocus();
        ref.read(numericKeyboardProvider.notifier).hideKeyboardOnly();
      }
    });
  }

  Widget _buildUnitsPerCartonField(ThemeData theme) {
    final currentUnit =
        _unitController.text.trim().isEmpty ? 'ج' : _unitController.text.trim();

    return InkWell(
      onTap: () => _openUnitsPerCartonKeyboard(currentUnit),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentUnit,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _unitsPerCartonController,
              builder: (context, value, _) {
                final raw = value.text.trim();
                final isPlaceholder = raw.isEmpty;
                final displayValue = isPlaceholder ? '12' : raw;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        displayValue,
                        textDirection: TextDirection.ltr,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPlaceholder
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'دانە',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isParentMode) {
      if (_variants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بۆ کاڵای فرە-جۆر، تکایە لانی کەم یەک جۆر زیاد بکە'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      for (final v in _variants) {
        if (v.variantNameCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تکایە ناوی هەموو جۆرەکان پڕبکەرەوە'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'barcode': _isParentMode ? '' : _barcodeController.text.trim(),
      'sku': _skuController.text.trim(),
      'cost_price': double.tryParse(_costPriceController.text) ?? 0,
      'price_n1': double.tryParse(_priceN1Controller.text) ?? 0,
      'price_n2': double.tryParse(_priceN2Controller.text) ?? 0,
      'price_n3': double.tryParse(_priceN3Controller.text) ?? 0,
      'units_per_carton': int.tryParse(_unitsPerCartonController.text) ?? 12,
      'unit': _unitController.text.trim().isEmpty ? 'ج' : _unitController.text.trim(),
      'category_id': _selectedCategoryId,
      'supplier_id': _selectedSupplierId,
      'is_active': _isActive ? 1 : 0,
      'is_parent': _isParentMode,
      'image_path': _imageUrlController.text.trim(),
    };

    if (_isParentMode) {
      data['variants'] = _variants.map((v) => v.toPayload()).toList();
      if (widget.product != null && _detachedVariantIds.isNotEmpty) {
        data['detached_variant_ids'] = _detachedVariantIds;
      }
    } else {
      data['initial_stock'] = double.tryParse(_stockController.text.trim()) ?? 0;
      data['min_stock_level'] = int.tryParse(_minStockController.text.trim()) ?? 0;
      if (_isEditingVariant) {
        data['variant_name'] = _variantNameController.text.trim();
        data['use_parent_price'] = _variantUseParentPrice;
      }
    }

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
    final selectedCategory = await showDialog<CategoryModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AddCategoryDialog(),
    );

    if (!mounted) return;

    if (selectedCategory != null) {
      setState(() {
        _selectedCategoryId = selectedCategory.id;
      });
      _categoryFieldKey.currentState?.didChange(selectedCategory.id);
    } else {
      setState(() {});
      _categoryFieldKey.currentState?.didChange(_selectedCategoryId);
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

                        // Parent / Variant mode banner or switch
                        if (_isEditingVariant && widget.product != null)
                          _buildEditingVariantBanner(theme, allProducts)
                        else if (widget.product == null ||
                            widget.product!.isParent ||
                            widget.product!.totalStock <= 0)
                          _buildMultiVariantModeToggle(theme),

                        // Basic Info
                        if (isMobile) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _nameController,
                                  labelText: _isParentMode
                                      ? 'ناوی سەرەکی کاڵا (نموونە: کێبڵ گلۆپ)'
                                      : 'ناوی کاڵا',
                                  hintText: _isParentMode
                                      ? 'ناوی گشتی کاڵا'
                                      : 'ناوی کاڵا',
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
                          if (!_isParentMode)
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
                            )
                          else
                            AppTextField(
                              controller: _skuController,
                              labelText: 'کۆدی گروپ (SKU)',
                              hintText: 'ئۆتۆماتیکی دروست دەکرێت ئەگەر بەتاڵ بێت',
                            ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: _isParentMode ? 6 : 2,
                                child: AppTextField(
                                  controller: _nameController,
                                  labelText: _isParentMode
                                      ? 'ناوی سەرەکی کاڵا (نموونە: کێبڵ گلۆپ)'
                                      : 'ناوی کاڵا',
                                  hintText: _isParentMode
                                      ? 'ناوی گشتی کاڵا'
                                      : 'ناوی کاڵا',
                                  validator: (v) =>
                                      v!.isEmpty ? 'ناوی کاڵا پێویستە' : null,
                                ),
                              ),
                              if (!_isParentMode) ...[
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
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 4,
                                child: AppTextField(
                                  controller: _skuController,
                                  labelText: _isParentMode ? 'کۆدی گروپ (SKU)' : 'SKU',
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
                                              key: _categoryFieldKey,
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
                        _buildUnifiedPricesGroup(
                          theme,
                          isMobile,
                          costController: _costPriceController,
                          priceN1Controller: _priceN1Controller,
                          priceN2Controller: _priceN2Controller,
                          priceN3Controller: _priceN3Controller,
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
                                        child: _buildUnitsPerCartonField(theme),
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
                                // Second row: Stock and Min Stock (hidden on parent container since each variant has its own stock)
                                if (!_isParentMode) ...[
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
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
                                  // Units per unit container
                                  Expanded(
                                    child: _buildUnitsPerCartonField(theme),
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
                                  if (!_isParentMode) ...[
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
                                ],
                              ),
                            ),
                          ),
                        if (_isParentMode) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildVariantsSection(theme, allProducts, isMobile),
                        ],
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

  Widget _buildUnifiedPricesGroup(
    ThemeData theme,
    bool isMobile, {
    required TextEditingController costController,
    required TextEditingController priceN1Controller,
    required TextEditingController priceN2Controller,
    required TextEditingController priceN3Controller,
  }) {
    InputDecoration fieldDecoration(String label, String hint) => InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        );

    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.4);

    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      customDecoration: fieldDecoration('کۆست', 'کۆست'),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: borderColor),
                  Expanded(
                    child: AppTextField(
                      controller: priceN1Controller,
                      keyboardType: TextInputType.number,
                      customDecoration: fieldDecoration('نرخی ١', 'N1'),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: priceN2Controller,
                      keyboardType: TextInputType.number,
                      customDecoration: fieldDecoration('نرخی ٢', 'N2'),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: borderColor),
                  Expanded(
                    child: AppTextField(
                      controller: priceN3Controller,
                      keyboardType: TextInputType.number,
                      customDecoration: fieldDecoration('نرخی ٣', 'N3'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: costController,
                keyboardType: TextInputType.number,
                customDecoration: fieldDecoration('کۆست', 'کۆست'),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: borderColor),
            Expanded(
              child: AppTextField(
                controller: priceN1Controller,
                keyboardType: TextInputType.number,
                customDecoration: fieldDecoration('نرخی ١', 'N1'),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: borderColor),
            Expanded(
              child: AppTextField(
                controller: priceN2Controller,
                keyboardType: TextInputType.number,
                customDecoration: fieldDecoration('نرخی ٢', 'N2'),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: borderColor),
            Expanded(
              child: AppTextField(
                controller: priceN3Controller,
                keyboardType: TextInputType.number,
                customDecoration: fieldDecoration('نرخی ٣', 'N3'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiVariantModeToggle(ThemeData theme) {
    final bool lockedAsParent =
        widget.product != null && widget.product!.isParent && _variants.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _isParentMode
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isParentMode
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.style_outlined,
            color: _isParentMode
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کاڵای فرە-جۆر / ڕەنگ (چەند جۆرێک لەژێر یەک ناو)',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                ),
                Text(
                  'نموونە: کێبڵ گلۆپ ← ئایفۆن، تایپسی، گالاکسی',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isParentMode,
            onChanged: lockedAsParent
                ? null
                : (val) {
                    setState(() {
                      _isParentMode = val;
                      if (val && _variants.isEmpty) {
                        _variants.add(_VariantDraftRow.empty());
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildEditingVariantBanner(
    ThemeData theme,
    List<ProductModel> allProducts,
  ) {
    final parent = allProducts
        .where((p) => p.id == widget.product?.parentId)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ئەم کاڵایە جۆرێکە لە: ${parent?.name ?? "کاڵای سەرەکی"}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final detached = await ref
                              .read(productActionsProvider)
                              .detachVariant(widget.product!.id);
                          if (mounted) {
                            Navigator.pop(context, detached);
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
                      },
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('جیاکردنەوە'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _variantNameController,
                  labelText: 'ناوی جۆر / ڕەنگ',
                  hintText: 'نموونە: ئایفۆن، سوور',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'ناوی جۆر پێویستە' : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('نرخی سەرەکی', style: AppTextStyles.caption),
                  Switch(
                    value: _variantUseParentPrice,
                    onChanged: (val) => setState(() {
                      _variantUseParentPrice = val;
                      if (val && parent != null) {
                        _costPriceController.text =
                            Formatters.cleanNumberString(parent.costPrice);
                        _priceN1Controller.text =
                            Formatters.cleanNumberString(parent.priceN1);
                        _priceN2Controller.text =
                            Formatters.cleanNumberString(parent.priceN2);
                        _priceN3Controller.text =
                            Formatters.cleanNumberString(parent.priceN3);
                      }
                    }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection(
    ThemeData theme,
    List<ProductModel> allProducts,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'جۆرەکان / ڕەنگەکان (${_variants.length})',
                    style: AppTextStyles.h3.copyWith(fontSize: 15),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAttachExistingProductDialog(allProducts),
                    icon: const Icon(Icons.link, size: 17),
                    label: const Text('لکاندنی کاڵای کۆن'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _variants.add(_VariantDraftRow.empty());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('جۆری نوێ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_variants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'هیچ جۆرێک زیاد نەکراوە. بەتنی "جۆری نوێ" یان "لکاندنی کاڵای کۆن" دابگرە.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _variants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = _variants[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: row.variantNameCtrl,
                              labelText: 'ناوی جۆر / ڕەنگ *',
                              hintText: 'نموونە: ئایفۆن / سوور / ١ لیتر',
                              validator: (val) => (val == null || val.trim().isEmpty)
                                  ? 'ناوی جۆر پێویستە'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (row.existingProductId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'لکێنراو',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              row.id != null ? Icons.link_off : Icons.delete_outline,
                              color: row.id != null ? AppColors.warning : AppColors.danger,
                              size: 20,
                            ),
                            tooltip: row.id != null
                                ? 'جیاکردنەوە و کردن بە کاڵای سەربەخۆ'
                                : 'لابردنی جۆر',
                            onPressed: () {
                              setState(() {
                                if (row.id != null) {
                                  _detachedVariantIds.add(row.id!);
                                }
                                final removed = _variants.removeAt(index);
                                removed.dispose();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isMobile) ...[
                        AppTextField(
                          controller: row.barcodeCtrl,
                          labelText: 'بارکۆد',
                          hintText: 'بارکۆد',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                                onPressed: () {
                                  CameraBarcodeScanner.show(context, (scanned) {
                                    setState(() => row.barcodeCtrl.text = scanned);
                                  }, closeOnScan: true);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code_2, size: 19, color: AppColors.primary),
                                onPressed: () {
                                  setState(() => row.barcodeCtrl.text = _generateRandomBarcode());
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: row.stockCtrl,
                                labelText: row.isExistingOrAttached ? 'ستۆکی سەرەکی' : 'ستۆک',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppTextField(
                                controller: row.minStockCtrl,
                                labelText: 'کەمترین بڕ',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: AppTextField(
                                controller: row.barcodeCtrl,
                                labelText: 'بارکۆد',
                                hintText: 'بارکۆد',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                                      onPressed: () {
                                        CameraBarcodeScanner.show(context, (scanned) {
                                          setState(() => row.barcodeCtrl.text = scanned);
                                        }, closeOnScan: true);
                                      },
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      icon: const Icon(Icons.qr_code_2, size: 19, color: AppColors.primary),
                                      onPressed: () {
                                        setState(() => row.barcodeCtrl.text = _generateRandomBarcode());
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: AppTextField(
                                controller: row.skuCtrl,
                                labelText: 'SKU',
                                hintText: 'SKU',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controller: row.stockCtrl,
                                labelText: row.isExistingOrAttached ? 'ستۆکی سەرەکی' : 'ستۆک',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controller: row.minStockCtrl,
                                labelText: 'کەمترین',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('نرخی سەرەکی'),
                            selected: row.useParentPrice,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => row.useParentPrice = true);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('نرخی تایبەت'),
                            selected: !row.useParentPrice,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  row.useParentPrice = false;
                                  if (row.costPriceCtrl.text.isEmpty) {
                                    row.costPriceCtrl.text = _costPriceController.text;
                                  }
                                  if (row.priceN1Ctrl.text.isEmpty) {
                                    row.priceN1Ctrl.text = _priceN1Controller.text;
                                  }
                                  if (row.priceN2Ctrl.text.isEmpty) {
                                    row.priceN2Ctrl.text = _priceN2Controller.text;
                                  }
                                  if (row.priceN3Ctrl.text.isEmpty) {
                                    row.priceN3Ctrl.text = _priceN3Controller.text;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (!row.useParentPrice) ...[
                        const SizedBox(height: 8),
                        _buildUnifiedPricesGroup(
                          theme,
                          isMobile,
                          costController: row.costPriceCtrl,
                          priceN1Controller: row.priceN1Ctrl,
                          priceN2Controller: row.priceN2Ctrl,
                          priceN3Controller: row.priceN3Ctrl,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showAttachExistingProductDialog(List<ProductModel> allProducts) async {
    final alreadyAddedIds = {
      for (final v in _variants)
        if (v.id != null) v.id! else if (v.existingProductId != null) v.existingProductId!,
    };
    final candidates = allProducts
        .where((p) =>
            !p.isParent &&
            !p.isVariant &&
            p.id != widget.product?.id &&
            !alreadyAddedIds.contains(p.id))
        .toList();

    String search = '';
    final picked = await showDialog<ProductModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = search.isEmpty
                ? candidates
                : candidates.where((p) {
                    return p.name.toLowerCase().contains(search) ||
                        p.barcode.toLowerCase().contains(search) ||
                        (p.sku != null && p.sku!.toLowerCase().contains(search));
                  }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 540),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'لکاندنی کاڵایەکی کۆن وەک جۆر',
                              style: AppTextStyles.h3,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => setDialogState(() {
                          search = v.trim().toLowerCase();
                        }),
                        decoration: InputDecoration(
                          hintText: 'گەڕان بە ناو یان بارکۆد...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('هیچ کاڵایەکی سەربەخۆ نەدۆزرایەوە'),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  return ListTile(
                                    title: Text(item.name, style: AppTextStyles.bodyBold),
                                    subtitle: Text(
                                      'ستۆک: ${Formatters.cleanNumberString(item.totalStock)} • N1: ${Formatters.currency(item.priceN1)}',
                                      style: AppTextStyles.caption,
                                    ),
                                    trailing: const Icon(Icons.add_link, color: AppColors.primary),
                                    onTap: () => Navigator.pop(ctx, item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;

    // Suggest variant label by stripping parent name prefix if user already typed parent name
    final parentName = _nameController.text.trim();
    String suggestedVariantName = picked.name;
    if (parentName.isNotEmpty &&
        picked.name.toLowerCase().startsWith(parentName.toLowerCase())) {
      final remainder = picked.name.substring(parentName.length).trim();
      final cleaned = remainder.replaceFirst(RegExp(r'^[-–—:\s]+'), '').trim();
      if (cleaned.isNotEmpty) {
        suggestedVariantName = cleaned;
      }
    }

    final double parentCost = double.tryParse(_costPriceController.text) ?? 0;
    final double parentN1 = double.tryParse(_priceN1Controller.text) ?? 0;
    final bool sameAsParentPrice = parentN1 <= 0 ||
        (picked.costPrice == parentCost && picked.priceN1 == parentN1);

    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = picked.name;
      }
      _selectedCategoryId ??= picked.categoryId;
      _selectedSupplierId ??= picked.supplierId;
      _variants.add(
        _VariantDraftRow.fromExistingProduct(
          picked,
          suggestedVariantName: suggestedVariantName,
          useParentPrice: sameAsParentPrice,
        ),
      );
    });
  }
}

class _VariantDraftRow {
  final int? id;
  final int? existingProductId;
  final TextEditingController variantNameCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController minStockCtrl;
  bool useParentPrice;
  final TextEditingController costPriceCtrl;
  final TextEditingController priceN1Ctrl;
  final TextEditingController priceN2Ctrl;
  final TextEditingController priceN3Ctrl;
  bool isActive;

  _VariantDraftRow({
    this.id,
    this.existingProductId,
    required this.variantNameCtrl,
    required this.barcodeCtrl,
    required this.skuCtrl,
    required this.stockCtrl,
    required this.minStockCtrl,
    this.useParentPrice = true,
    required this.costPriceCtrl,
    required this.priceN1Ctrl,
    required this.priceN2Ctrl,
    required this.priceN3Ctrl,
    this.isActive = true,
  });

  bool get isExistingOrAttached => id != null || existingProductId != null;

  factory _VariantDraftRow.empty() {
    return _VariantDraftRow(
      variantNameCtrl: TextEditingController(),
      barcodeCtrl: TextEditingController(),
      skuCtrl: TextEditingController(),
      stockCtrl: TextEditingController(text: '0'),
      minStockCtrl: TextEditingController(text: '0'),
      useParentPrice: true,
      costPriceCtrl: TextEditingController(),
      priceN1Ctrl: TextEditingController(),
      priceN2Ctrl: TextEditingController(),
      priceN3Ctrl: TextEditingController(),
      isActive: true,
    );
  }

  factory _VariantDraftRow.fromProduct(ProductModel child) {
    double mainStock = 0;
    int minStock = 0;
    for (final s in child.stocks) {
      if (s is Map) {
        mainStock += Formatters.parseDouble(s['quantity']);
        if (s['min_stock_level'] != null && minStock == 0) {
          minStock = Formatters.parseInt(s['min_stock_level']);
        }
      }
    }
    return _VariantDraftRow(
      id: child.id,
      variantNameCtrl: TextEditingController(text: child.displayVariantLabel),
      barcodeCtrl: TextEditingController(text: child.barcode),
      skuCtrl: TextEditingController(text: child.sku ?? ''),
      stockCtrl: TextEditingController(
        text: Formatters.cleanNumberString(mainStock),
      ),
      minStockCtrl: TextEditingController(text: '$minStock'),
      useParentPrice: child.useParentPrice,
      costPriceCtrl: TextEditingController(
        text: Formatters.cleanNumberString(child.costPrice),
      ),
      priceN1Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(child.priceN1),
      ),
      priceN2Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(child.priceN2),
      ),
      priceN3Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(child.priceN3),
      ),
      isActive: child.isActive,
    );
  }

  factory _VariantDraftRow.fromExistingProduct(
    ProductModel existing, {
    required String suggestedVariantName,
    required bool useParentPrice,
  }) {
    double mainStock = 0;
    int minStock = 0;
    for (final s in existing.stocks) {
      if (s is Map) {
        mainStock += Formatters.parseDouble(s['quantity']);
        if (s['min_stock_level'] != null && minStock == 0) {
          minStock = Formatters.parseInt(s['min_stock_level']);
        }
      }
    }
    return _VariantDraftRow(
      existingProductId: existing.id,
      variantNameCtrl: TextEditingController(text: suggestedVariantName),
      barcodeCtrl: TextEditingController(text: existing.barcode),
      skuCtrl: TextEditingController(text: existing.sku ?? ''),
      stockCtrl: TextEditingController(
        text: Formatters.cleanNumberString(mainStock),
      ),
      minStockCtrl: TextEditingController(text: '$minStock'),
      useParentPrice: useParentPrice,
      costPriceCtrl: TextEditingController(
        text: Formatters.cleanNumberString(existing.costPrice),
      ),
      priceN1Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(existing.priceN1),
      ),
      priceN2Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(existing.priceN2),
      ),
      priceN3Ctrl: TextEditingController(
        text: Formatters.cleanNumberString(existing.priceN3),
      ),
      isActive: existing.isActive,
    );
  }

  Map<String, dynamic> toPayload() {
    final map = <String, dynamic>{
      if (id != null) 'id': id,
      if (existingProductId != null) 'existing_product_id': existingProductId,
      'variant_name': variantNameCtrl.text.trim(),
      'barcode': barcodeCtrl.text.trim(),
      'sku': skuCtrl.text.trim(),
      'use_parent_price': useParentPrice,
      'is_active': isActive,
      'min_stock_level': int.tryParse(minStockCtrl.text.trim()) ?? 0,
    };
    if (!isExistingOrAttached || stockCtrl.text.trim().isNotEmpty) {
      map['initial_stock'] = double.tryParse(stockCtrl.text.trim()) ?? 0;
    }
    if (!useParentPrice) {
      map['cost_price'] = double.tryParse(costPriceCtrl.text.trim()) ?? 0;
      map['price_n1'] = double.tryParse(priceN1Ctrl.text.trim()) ?? 0;
      map['price_n2'] = double.tryParse(priceN2Ctrl.text.trim()) ?? 0;
      map['price_n3'] = double.tryParse(priceN3Ctrl.text.trim()) ?? 0;
    }
    return map;
  }

  void dispose() {
    variantNameCtrl.dispose();
    barcodeCtrl.dispose();
    skuCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    costPriceCtrl.dispose();
    priceN1Ctrl.dispose();
    priceN2Ctrl.dispose();
    priceN3Ctrl.dispose();
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

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  String? _confirmedSimilarName;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {
      _inlineError = null;
      if (_confirmedSimilarName != _controller.text.trim()) {
        _confirmedSimilarName = null;
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(List<CategoryModel> categories) async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _inlineError = 'ناوی کاتیگۆری پێویستە';
      });
      return;
    }

    final exactMatch = CategorySimilarityHelper.findExactMatch(
      trimmed,
      categories,
    );
    if (exactMatch != null) {
      setState(() {
        _inlineError =
            'ئەم کاتیگۆرییە پێشتر بە ناوی «${exactMatch.category.name}» بوونی هەیە!';
      });
      return;
    }

    final matches = CategorySimilarityHelper.findMatches(trimmed, categories);
    if (matches.isNotEmpty && _confirmedSimilarName != trimmed) {
      setState(() {
        _confirmedSimilarName = trimmed;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    try {
      final newCategory = await ref
          .read(categoryActionsProvider)
          .addCategory(trimmed);
      if (mounted) {
        Navigator.pop(context, newCategory);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isSaving = false;
          _inlineError = 'کێشە لە زیادکردنی کاتیگۆری: $message';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <CategoryModel>[];
    final allProducts = ref.watch(productsListProvider).valueOrNull;
    final Map<int, int>? liveCounts = allProducts == null
        ? null
        : allProducts.fold<Map<int, int>>({}, (map, p) {
            final cid = p.categoryId;
            if (cid != null) {
              map[cid] = (map[cid] ?? 0) + 1;
            }
            return map;
          });

    final trimmed = _controller.text.trim();
    final matches = CategorySimilarityHelper.findMatches(trimmed, categories);
    final hasExact = matches.any((m) => m.isExact);
    final needsConfirmation =
        !hasExact && matches.isNotEmpty && _confirmedSimilarName == trimmed;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: Text('زیادکردنی کاتیگۆری نوێ')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(categories),
                contextMenuBuilder: (context, editableTextState) {
                  return KurdishContextMenu.build(context, editableTextState);
                },
                decoration: InputDecoration(
                  hintText: 'ناوی کاتیگۆری',
                  errorText: matches.isEmpty ? _inlineError : null,
                ),
              ),
              CategorySimilarityBanner(
                matches: matches,
                liveCounts: liveCounts,
                needsConfirmation: needsConfirmation,
                inlineError: matches.isNotEmpty ? _inlineError : null,
                onSelectCategory: _isSaving
                    ? null
                    : (category) => Navigator.pop(context, category),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => _submit(categories),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  needsConfirmation ? 'دڵنیام، زیادی بکە' : 'زیادکردن',
                  style: needsConfirmation
                      ? TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.warningDark
                              : AppColors.warning,
                          fontWeight: FontWeight.bold,
                        )
                      : null,
                ),
        ),
      ],
    );
  }
}
