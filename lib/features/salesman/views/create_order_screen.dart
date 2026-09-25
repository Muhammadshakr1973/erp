import 'dart:async';
import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/customer_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  final int? preselectedCustomerId;
  final OrderModel? existingOrder;

  const CreateOrderScreen({
    super.key,
    this.preselectedCustomerId,
    this.existingOrder,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  Customer? _selectedCustomer;
  int? _selectedWarehouseId;
  final Map<int, int> _cart = {}; // product_id -> quantity
  final Map<int, String> _cartNotes = {}; // product_id -> notes
  Timer? _debounceTimer;
  Map<int, double> _customerSpecialPrices = {}; // product_id -> special unit price
  String _discountType = 'PERCENT';
  double _discountValue = 0.0;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double? _searchFieldWidth;
  final GlobalKey _searchKey = GlobalKey();

  String? _localId;
  int? _generatedIntId;
  String? _sharedKey;
  bool _hasSavedOnce = false;
  bool _isSaving = false;

  String? _lastChangedField;
  final Map<String, String> _fieldStates = {}; // field_name -> 'saving' | 'success' | 'error'
  final Map<String, String> _fieldErrors = {}; // field_name -> error message
  final Map<String, Timer> _successTimers = {};

  void _setFieldState(String field, String state, {String? error}) {
    if (!mounted) return;
    if (_fieldStates[field] == state && _fieldErrors[field] == error) {
      return;
    }
    setState(() {
      _fieldStates[field] = state;
      if (error != null) {
        _fieldErrors[field] = error;
      } else {
        _fieldErrors.remove(field);
      }
    });

    if (state == 'success') {
      _successTimers[field]?.cancel();
      _successTimers[field] = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _fieldStates.remove(field);
          });
        }
        _successTimers.remove(field);
      });
    }
  }

  Widget? _buildFieldStatusIcon(String field, {double size = 20}) {
    final state = _fieldStates[field];
    if (state == 'saving') {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      );
    } else if (state == 'success') {
      return Icon(Icons.check_circle, color: AppColors.success, size: size);
    } else if (state == 'error') {
      final errorMsg = _fieldErrors[field] ?? 'هەڵەیەک ڕوویدا';
      return Tooltip(
        message: errorMsg,
        preferBelow: false,
        child: Icon(Icons.error, color: AppColors.danger, size: size),
      );
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final cleanStr = _localId!.replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(cleanStr) ?? 0;
    _generatedIntId = -1 * (val % 1000000000);
    _sharedKey = 'order_${DateTime.now().microsecondsSinceEpoch}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.existingOrder != null) {
        _populateFromExistingOrder(widget.existingOrder!);
      } else if (widget.preselectedCustomerId != null) {
        _loadPreselectedCustomer();
      }
    });
  }

  void _populateFromExistingOrder(OrderModel order) {
    setState(() {
      _localId = order.id.toString();
      _generatedIntId = order.id;
      _sharedKey = order.sharedKey;
      _hasSavedOnce = true;
      _selectedWarehouseId = order.warehouseId;
      _discountType = order.discountType;
      _discountValue = order.discountType == 'PERCENT'
          ? order.discountPercent
          : order.discountAmount;
      if (order.notes != null) {
        _notesController.text = order.notes!;
      }
      for (var item in order.items) {
        _cart[item.productId] = item.quantity.toInt();
        if (item.notes != null) {
          _cartNotes[item.productId] = item.notes!;
        }
      }
    });
    _loadCustomerById(order.customerId);
  }

  void _loadCustomerById(int customerId) async {
    final customers = await ref.read(customerListProvider.future);
    final match = customers.where((c) => c.id == customerId).firstOrNull;
    if (match != null && mounted) {
      setState(() {
        _selectedCustomer = match;
      });
      _fetchSpecialPricesForCustomer(match.id);
    }
  }

  void _loadPreselectedCustomer() async {
    final customers = await ref.read(customerListProvider.future);
    final match = customers
        .where((c) => c.id == widget.preselectedCustomerId)
        .firstOrNull;
    if (match != null && mounted) {
      setState(() {
        _selectedCustomer = match;
      });
      _fetchSpecialPricesForCustomer(match.id);
    }
  }

  Future<void> _fetchSpecialPricesForCustomer(int customerId) async {
    try {
      final prices = await ref
          .read(customerActionsProvider)
          .fetchSpecialPrices(customerId);
      if (mounted) {
        setState(() {
          _customerSpecialPrices = prices;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _notesController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (var timer in _successTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  double _getProductUnitPrice(ProductModel product) {
    if (_selectedCustomer == null) {
      return product.priceN2 > 0 ? product.priceN2 : product.costPrice;
    }
    // پشکنینی ئەوەی کە ئایا نرخی تایبەت بۆ ئەم کاڵایە هەیە بۆ ئەم کڕیارە
    if (_customerSpecialPrices.containsKey(product.id)) {
      return _customerSpecialPrices[product.id]!;
    }
    final tier = _selectedCustomer!.priceType?.toUpperCase() ?? 'N2';
    switch (tier) {
      case 'N1':
        return product.priceN1 > 0 ? product.priceN1 : product.costPrice;
      case 'N3':
        return product.priceN3 > 0 ? product.priceN3 : product.costPrice;
      case 'N2':
      default:
        return product.priceN2 > 0 ? product.priceN2 : product.costPrice;
    }
  }

  double _calculateSubtotal(List<ProductModel> products) {
    double total = 0.0;
    _cart.forEach((productId, qty) {
      final product = products.where((p) => p.id == productId).firstOrNull;
      if (product != null) {
        total += _getProductUnitPrice(product) * qty;
      }
    });
    return total;
  }

  void _addToCart(int productId) {
    _lastChangedField = 'product_qty_$productId';
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
    _triggerDebouncedAutoSave();
  }

  void _removeFromCart(int productId) {
    _lastChangedField = 'product_qty_$productId';
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]! > 1) {
          _cart[productId] = _cart[productId]! - 1;
        } else {
          _cart.remove(productId);
          _cartNotes.remove(productId);
        }
      }
    });
    _triggerDebouncedAutoSave();
  }

  Future<void> _confirmDeleteItem(int productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی کاڵا', style: AppTextStyles.h3),
        content: Text(
          'ئایا دڵنیایت لە سڕینەوەی "$productName" لە پسوڵەکەدا؟',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _cart.remove(productId);
        _cartNotes.remove(productId);
      });
      _triggerDebouncedAutoSave();
      AppSnackbar.show(
        context,
        message: '$productName لە پسوڵەکە سڕایەوە',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _editQuantityDialog(
    int productId,
    int currentQty,
    String productName,
  ) async {
    final controller = TextEditingController(text: currentQty.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('دەستکاری بڕی $productName', style: AppTextStyles.h3),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'بڕ (دانە)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, parsed);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('تەواو'),
          ),
        ],
      ),
    );

    if (newQty != null && newQty > 0 && mounted) {
      _lastChangedField = 'product_qty_$productId';
      setState(() {
        _cart[productId] = newQty;
      });
      _triggerDebouncedAutoSave();
    }
  }

  Future<void> _showSpecialPriceDialog(ProductModel product) async {
    if (_selectedCustomer == null) {
      AppSnackbar.show(
        context,
        message: 'تکایە سەرەتا کڕیارێک هەڵبژێرە بۆ دانانی نرخی تایبەت',
        type: SnackbarType.warning,
      );
      return;
    }

    final hasSpecial = _customerSpecialPrices.containsKey(product.id);
    final currentSpecial = _customerSpecialPrices[product.id];
    final defaultPrice = _selectedCustomer!.priceType?.toUpperCase() == 'N1'
        ? (product.priceN1 > 0 ? product.priceN1 : product.costPrice)
        : (_selectedCustomer!.priceType?.toUpperCase() == 'N3'
            ? (product.priceN3 > 0 ? product.priceN3 : product.costPrice)
            : (product.priceN2 > 0 ? product.priceN2 : product.costPrice));

    final controller = TextEditingController(
      text: hasSpecial
          ? currentSpecial!.toInt().toString()
          : defaultPrice.toInt().toString(),
    );

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (modalCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.sell_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'دانانی نرخی تایبەت بۆ ${_selectedCustomer!.name}',
                    style: AppTextStyles.h3,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کاڵا: ${product.name}',
                    style: AppTextStyles.bodyBold,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نرخی بنەڕەتی کڕیار (${_selectedCustomer!.priceType ?? 'N2'}): ${Formatters.currency(defaultPrice)}',
                    style: AppTextStyles.caption,
                  ),
                  if (hasSpecial) ...[
                    const SizedBox(height: 4),
                    Text(
                      'نرخی تایبەتی ئێستا: ${Formatters.currency(currentSpecial!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'نرخی تایبەتی نوێ (دینار)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (hasSpecial)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            await ref
                                .read(customerActionsProvider)
                                .deleteSpecialPrice(
                                  _selectedCustomer!.id,
                                  product.id,
                                );
                            setState(() {
                              _customerSpecialPrices.remove(product.id);
                            });
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              AppSnackbar.show(
                                context,
                                message:
                                    'نرخی تایبەت سڕایەوە و گەڕایەوە بۆ نرخی بنەڕەتی',
                                type: SnackbarType.info,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              AppSnackbar.show(
                                context,
                                message: 'هەڵە لە سڕینەوە: $e',
                                type: SnackbarType.error,
                              );
                            }
                          } finally {
                            if (modalCtx.mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  child: const Text('سڕینەوەی تایبەت'),
                ),
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('پاشگەزبوونەوە'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final parsed = double.tryParse(controller.text.trim());
                        if (parsed == null || parsed < 0) {
                          AppSnackbar.show(
                            context,
                            message: 'تکایە نرخێکی دروست بنووسە',
                            type: SnackbarType.warning,
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await ref
                              .read(customerActionsProvider)
                              .setSpecialPrice(
                                _selectedCustomer!.id,
                                product.id,
                                parsed,
                              );
                          setState(() {
                            _customerSpecialPrices[product.id] = parsed;
                          });
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            AppSnackbar.show(
                              context,
                              message:
                                  'نرخی تایبەت بە سەرکەوتوویی بۆ ئەم کڕیارە پاشەکەوتکرا (${Formatters.currency(parsed)})',
                              type: SnackbarType.success,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackbar.show(
                              context,
                              message: 'هەڵە لە پاشەکەوتکردن: $e',
                              type: SnackbarType.error,
                            );
                          }
                        } finally {
                          if (modalCtx.mounted) setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('پاشەکەوتکردن'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scanBarcode(List<ProductModel> products) {
    CameraBarcodeScanner.show(context, (scannedBarcode) {
      final matched = products
          .where((p) => p.barcode == scannedBarcode || p.sku == scannedBarcode)
          .firstOrNull;
      if (matched != null) {
        _addToCart(matched.id);
        AppSnackbar.show(
          context,
          message: '${matched.name} زیادکرا بۆ سەبەتە',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'هیچ کاڵایەک نەدۆزرایەوە بە کۆدی: $scannedBarcode',
          type: SnackbarType.error,
        );
      }
    });
  }

  Future<void> _autoSaveOrder(
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) async {
    if (warehousesAsync.hasError || warehousesAsync.asData == null) return;

    final warehouses = warehousesAsync.asData!.value;
    if (warehouses.isEmpty) return;
    if (_selectedCustomer == null) return;
    if (widget.existingOrder == null && _cart.isEmpty) return;

    final warehouseId = _selectedWarehouseId ??
        (warehouses.any((w) => w.isMain)
            ? warehouses.firstWhere((w) => w.isMain).id
            : warehouses.first.id);

    final List<Map<String, dynamic>> itemsList = [];
    _cart.forEach((productId, qty) {
      itemsList.add({
        'product_id': productId,
        'quantity': qty,
        'notes': _cartNotes[productId],
      });
    });

    final String sharedKey = _sharedKey ?? 'order_${DateTime.now().microsecondsSinceEpoch}';
    final int version = widget.existingOrder?.version ?? 1;

    final payload = {
      'customer_id': _selectedCustomer!.id,
      'warehouse_id': warehouseId,
      'status': 'PACKING',
      'discount_type': _discountType,
      'discount_percent': _discountType == 'PERCENT' ? _discountValue : null,
      'discount_amount': _discountType == 'FIXED' ? _discountValue : null,
      'shared_key': sharedKey,
      'version': version,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'items': itemsList,
    };

    if (mounted) {
      setState(() {
        _isSaving = true;
        if (_lastChangedField != null) {
          _fieldStates[_lastChangedField!] = 'saving';
        }
      });
    }

    try {
      if (_hasSavedOnce) {
        final orderIdToUpdate = widget.existingOrder?.id ?? _generatedIntId!;
        await ref
            .read(orderActionsProvider)
            .updateOrder(orderIdToUpdate, payload);
      } else {
        payload['local_id'] = _localId!;
        await ref.read(orderActionsProvider).createOrder(payload);
        _hasSavedOnce = true;
      }

      if (mounted && _lastChangedField != null) {
        _setFieldState(_lastChangedField!, 'success');
        _lastChangedField = null;
      }
    } catch (e) {
      if (mounted && _lastChangedField != null) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        _setFieldState(_lastChangedField!, 'error', error: errorMsg);
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('پاشەکەوتکردن سەرکەوتوو نەبوو: $errorMsg'),
            backgroundColor: AppColors.danger,
          ),
        );
        _lastChangedField = null;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _triggerAutoSave() {
    final productsAsync = ref.read(productsListProvider);
    final warehousesAsync = ref.read(warehouseListProvider);
    if (productsAsync.asData != null && warehousesAsync.asData != null) {
      _autoSaveOrder(warehousesAsync);
    }
  }

  void _triggerDebouncedAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _triggerAutoSave();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'orders.create',
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (_debounceTimer?.isActive == true) {
            _debounceTimer?.cancel();
            _triggerAutoSave();
          }
        },
        child: _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final customersAsync = ref.watch(customerListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    final allProducts = productsAsync.asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: _buildCustomerSelectionDropdown(
                    customersAsync,
                  ),
                ),
              ),
              if (_isSaving) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopOrTablet =
              constraints.maxWidth >= AppBreakpoints.tabletMin;

          return Column(
            children: [
              // 1. Customer & Warehouse Selection Bar
              _buildTopBar(customersAsync, warehousesAsync),

              // 2. Product selection & Cart Split
              Expanded(
                child: isDesktopOrTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildProductSelectionSection(
                              productsAsync,
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            flex: 1,
                            child: _buildCartPanel(allProducts),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          if (productsAsync.isLoading)
                            const LinearProgressIndicator(),
                          Expanded(
                            child: _buildCartPanel(allProducts),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    AsyncValue<List<Customer>> customersAsync,
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Notes Input (replaces Customer Selection)
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: _notesController,
              hintText: 'تێبینی (ئارەزوومەندانە)...',
              prefixIcon: Icons.note_alt_outlined,
              suffixIcon: _buildFieldStatusIcon('order_notes'),
              borderRadius: BorderRadius.circular(8),
              onChanged: (val) {
                _lastChangedField = 'order_notes';
                _triggerDebouncedAutoSave();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // 2. Warehouse Selection
          Expanded(
            flex: 2,
            child: warehousesAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, _) => const Text('هەڵە لە کۆگا'),
              data: (warehouses) {
                if (warehouses.isEmpty) {
                  return const Text('کۆگا نییە');
                }
                final selectedId = _selectedWarehouseId ??
                    (warehouses.any((w) => w.isMain)
                        ? warehouses.firstWhere((w) => w.isMain).id
                        : warehouses.first.id);

                return DropdownButtonFormField<int>(
                  key: ValueKey(selectedId),
                  initialValue: warehouses.any((w) => w.id == selectedId)
                      ? selectedId
                      : warehouses.first.id,
                  decoration: InputDecoration(
                    labelText: 'دیاریکردنی کۆگا',
                    prefixIcon: const Icon(Icons.warehouse_outlined, size: 20),
                    suffixIcon: _buildFieldStatusIcon('warehouse'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                  items: warehouses.map((w) {
                    return DropdownMenuItem<int>(
                      value: w.id,
                      child: Text(
                        w.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _lastChangedField = 'warehouse';
                      setState(() {
                        _selectedWarehouseId = val;
                      });
                      _triggerDebouncedAutoSave();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelectionSection(
    AsyncValue<List<ProductModel>> productsAsync,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (productsAsync.isLoading)
          const LinearProgressIndicator(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code_scanner,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'گەڕان بەپێی ناوی کاڵا یان باڕکۆد',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'لە ڕێگەی ئینپوتی گەڕانی سەرەوەی سەبەتە بە ناوی کاڵا یان باڕکۆد بگەڕێ بۆ ئەوەی ڕاستەوخۆ کاڵا زیادبکەیت بۆ پسوڵەکە',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductAutocompleteInput(
    List<ProductModel> allProducts,
  ) {
    final theme = Theme.of(context);

    return RawAutocomplete<ProductModel>(
      textEditingController: _searchController,
      focusNode: _searchFocusNode,
      displayStringForOption: (ProductModel option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<ProductModel>.empty();
        }

        final matches = allProducts.where((p) {
          final nameMatches = p.name.toLowerCase().contains(query);
          final barcodeMatches = p.barcode.toLowerCase().contains(query);
          final skuMatches =
              p.sku != null && p.sku!.toLowerCase().contains(query);
          return nameMatches || barcodeMatches || skuMatches;
        }).toList();

        // Sort: exact barcode first, startsWith barcode/name next, then alphabetical
        matches.sort((a, b) {
          final aExactBarcode = a.barcode.toLowerCase() == query;
          final bExactBarcode = b.barcode.toLowerCase() == query;
          if (aExactBarcode && !bExactBarcode) return -1;
          if (!aExactBarcode && bExactBarcode) return 1;

          final aBarcodeStarts = a.barcode.toLowerCase().startsWith(query);
          final bBarcodeStarts = b.barcode.toLowerCase().startsWith(query);
          if (aBarcodeStarts && !bBarcodeStarts) return -1;
          if (!aBarcodeStarts && bBarcodeStarts) return 1;

          final aNameStarts = a.name.toLowerCase().startsWith(query);
          final bNameStarts = b.name.toLowerCase().startsWith(query);
          if (aNameStarts && !bNameStarts) return -1;
          if (!aNameStarts && bNameStarts) return 1;

          return a.name.compareTo(b.name);
        });

        return matches;
      },
      onSelected: (ProductModel selection) {
        _handleProductSelected(selection);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return LayoutBuilder(
          builder: (context, constraints) {
            _searchFieldWidth = constraints.maxWidth;

            return Container(
              key: _searchKey,
              child: AppTextField(
                controller: textEditingController,
                focusNode: focusNode,
                hintText: 'گەڕان بەپێی ناوی کاڵا یان باڕکۆد...',
                prefixIcon: AppIcons.search,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (textEditingController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'سڕینەوەی دەق',
                        onPressed: () {
                          textEditingController.clear();
                          focusNode.requestFocus();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: const Icon(AppIcons.scan),
                      tooltip: 'سکانی باڕکۆد',
                      onPressed: () => _scanBarcode(allProducts),
                    ),
                  ],
                ),
                onChanged: (_) {
                  setState(() {});
                },
                onFieldSubmitted: (_) {
                  _handleBarcodeOrSearchSubmit(
                    textEditingController,
                    focusNode,
                    allProducts,
                  );
                },
              ),
            );
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<ProductModel> onSelected,
        Iterable<ProductModel> options,
      ) {
        final screenWidth = MediaQuery.of(context).size.width;

        final RenderBox? renderBox = _searchKey.currentContext?.findRenderObject() as RenderBox?;
        final position = renderBox?.localToGlobal(Offset.zero);
        final textFieldX = position?.dx ?? 0.0;

        final isMobile = screenWidth < 600;
        final double dropdownWidth = isMobile
            ? screenWidth
            : (_searchFieldWidth != null
                ? (_searchFieldWidth! > (screenWidth - 32) ? (screenWidth - 32) : _searchFieldWidth!)
                : (screenWidth > 450 ? 450.0 : screenWidth - 32));
        final double xOffset = isMobile ? -textFieldX : 0.0;

        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Transform.translate(
              offset: Offset(xOffset, 0),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: theme.colorScheme.surface,
                child: SizedBox(
                  width: dropdownWidth,
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = options.elementAt(index);
                      final unitPrice = _getProductUnitPrice(product);
                      final qtyInCart = _cart[product.id] ?? 0;

                      return InkWell(
                        onTap: () => onSelected(product),
                        onLongPress: () {
                          _addToCart(product.id);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} زیادکرا بۆ سەبەتە'),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (product.imagePath != null &&
                                        product.imagePath!.isNotEmpty)
                                    ? GestureDetector(
                                        onTap: () {
                                          _showLargeImageDialog(context, product.imagePath!, product.name);
                                        },
                                        child: Image.network(
                                          product.imagePath!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.inventory_2_outlined,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.inventory_2_outlined,
                                        color: theme.colorScheme.primary,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product.name,
                                            style: AppTextStyles.bodyBold,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (qtyInCart > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$qtyInCart لە سەبەتەدا',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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
                                        if (product.barcode.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.qr_code,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                product.barcode,
                                                style: AppTextStyles.caption.copyWith(
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        Text(
                                          'یەکە: ${product.unit ?? "دانە"}',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                Formatters.currency(unitPrice),
                                style: AppTextStyles.price,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildCustomerSelectionDropdown(
    AsyncValue<List<Customer>> customersAsync,
  ) {
    final theme = Theme.of(context);

    return customersAsync.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      ),
      error: (error, stackTrace) => const Text(
        'هەڵە لە بارکردنی کڕیاران',
        style: TextStyle(color: Colors.white, fontSize: 11),
      ),
      data: (customers) {
        return DropdownButtonFormField<int>(
          key: ValueKey(_selectedCustomer?.id),
          initialValue: customers.any((c) => c.id == _selectedCustomer?.id)
              ? _selectedCustomer?.id
              : null,
          decoration: InputDecoration(
            labelText: 'دیاریکردنی کڕیار',
            labelStyle: TextStyle(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 11,
              fontFamily: 'Rudaw',
            ),
            prefixIcon: Icon(
              Icons.person_outline,
              size: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
            suffixIcon: _buildFieldStatusIcon('customer', size: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.onPrimary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),
          dropdownColor: theme.colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontFamily: 'Rudaw',
          ),
          iconEnabledColor: theme.colorScheme.onPrimary,
          items: customers.map((c) {
            return DropdownMenuItem<int>(
              value: c.id,
              child: Text(
                c.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  fontFamily: 'Rudaw',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            final found = customers.where((c) => c.id == val).firstOrNull;
            _lastChangedField = 'customer';
            setState(() {
              _selectedCustomer = found;
            });
            if (found != null) {
              _fetchSpecialPricesForCustomer(found.id);
            }
            _triggerDebouncedAutoSave();
          },
        );
      },
    );
  }

  void _showLargeImageDialog(BuildContext context, String imageUrl, String productName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          color: Theme.of(context).colorScheme.surface,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text('بارکردنی وێنەکە سەرکەوتوو نەبوو', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Rudaw',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleProductSelected(ProductModel selection) {
    _addToCart(selection.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selection.name} زیادکرا بۆ سەبەتە'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.clear();
      _searchFocusNode.requestFocus();
    });
  }

  void _handleBarcodeOrSearchSubmit(
    TextEditingController controller,
    FocusNode focusNode,
    List<ProductModel> allProducts,
  ) {
    final query = controller.text.trim();
    if (query.isEmpty) return;

    final lowerQuery = query.toLowerCase();

    // 1. Exact barcode match
    ProductModel? match = allProducts
        .where((p) => p.barcode.toLowerCase() == lowerQuery)
        .firstOrNull;

    // 2. Exact SKU match
    match ??= allProducts
        .where((p) => p.sku != null && p.sku!.toLowerCase() == lowerQuery)
        .firstOrNull;

    // 3. Exact name match
    match ??= allProducts
        .where((p) => p.name.toLowerCase() == lowerQuery)
        .firstOrNull;

    // 4. Barcode starts with query
    match ??= allProducts
        .where((p) => p.barcode.toLowerCase().startsWith(lowerQuery))
        .firstOrNull;

    // 5. Name contains query
    match ??= allProducts
        .where((p) => p.name.toLowerCase().contains(lowerQuery))
        .firstOrNull;

    if (match != null) {
      _addToCart(match.id);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${match.name} زیادکرا بۆ سەبەتە'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
      controller.clear();
      focusNode.requestFocus();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هیچ کاڵایەک نەدۆزرایەوە بە: $query'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildCartPanel(
    List<ProductModel> allProducts,
  ) {
    final theme = Theme.of(context);
    final subtotal = _calculateSubtotal(allProducts);
    final permDiscountPercent = _selectedCustomer?.permanentDiscount ?? 0.0;
    final permDiscountAmount = (subtotal * permDiscountPercent) / 100;
    final amountAfterPerm = subtotal - permDiscountAmount;
    final invoiceDiscountAmount = _discountType == 'PERCENT' 
        ? (amountAfterPerm * _discountValue) / 100 
        : _discountValue;
    final totalAmount = amountAfterPerm - invoiceDiscountAmount;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildProductAutocompleteInput(allProducts),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sell_outlined, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCustomer != null
                            ? (_selectedCustomer!.priceType ?? 'N2')
                            : 'N2',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'سەبەتە بەتاڵە',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final cartKeys = _cart.keys.toList();
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: cartKeys.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final productId = cartKeys[index];
                          final qty = _cart[productId]!;
                          final product = allProducts
                              .where((p) => p.id == productId)
                              .firstOrNull;
                          final unitPrice = product != null
                              ? _getProductUnitPrice(product)
                              : 0.0;
                          final isSpecialPrice =
                              _customerSpecialPrices.containsKey(productId);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: product != null
                                  ? () => _showSpecialPriceDialog(product)
                                  : null,
                              onLongPress: () => _confirmDeleteItem(
                                productId,
                                product?.name ?? 'کاڵا',
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSpecialPrice
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor.withValues(alpha: 0.3),
                                    width: isSpecialPrice ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSpecialPrice
                                      ? theme.colorScheme.primary.withValues(alpha: 0.05)
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      product?.name ?? 'کاڵا',
                                                      style: AppTextStyles.bodyBold,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isSpecialPrice)
                                                    const SizedBox(width: 4),
                                                  if (isSpecialPrice)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.primary,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'نرخی تایبەت',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          // ignore: deprecated_member_use
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '(${product?.unit ?? "پاکەت"} = ${product?.unitsPerCarton ?? 12} دانە = ${Formatters.currency(unitPrice)})',
                                                style: AppTextStyles.caption.copyWith(
                                                  color: isSpecialPrice
                                                      ? theme.colorScheme.primary
                                                      : null,
                                                  fontWeight: isSpecialPrice
                                                      ? FontWeight.bold
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_buildFieldStatusIcon('product_qty_$productId', size: 18) != null) ...[
                                                  _buildFieldStatusIcon('product_qty_$productId', size: 18)!,
                                                  const SizedBox(width: 4),
                                                ],
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.add_circle_outline,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  onPressed: () => _addToCart(productId),
                                                ),
                                                InkWell(
                                                  onTap: () => _editQuantityDialog(
                                                    productId,
                                                    qty,
                                                    product?.name ?? 'کاڵا',
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '$qty',
                                                          style: AppTextStyles.bodyBold
                                                              .copyWith(
                                                            decoration:
                                                                TextDecoration.underline,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          product?.unit ?? 'دانە',
                                                          style: AppTextStyles.caption.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    color: AppColors.danger,
                                                  ),
                                                  onPressed: () =>
                                                      _removeFromCart(productId),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'کۆ: ${Formatters.currency(unitPrice * qty)}',
                                              style: AppTextStyles.caption.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 8, thickness: 0.5),
                                    Row(
                                      children: [
                                        const Icon(Icons.note_alt_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _cartNotes[productId] ?? '',
                                            style: const TextStyle(fontSize: 11),
                                            decoration: InputDecoration(
                                              hintText: 'تێبینی بۆ ئەم کاڵایە...',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                              border: InputBorder.none,
                                              suffixIcon: _buildFieldStatusIcon('product_note_$productId', size: 16),
                                              suffixIconConstraints: const BoxConstraints(
                                                minWidth: 16,
                                                minHeight: 16,
                                              ),
                                            ),
                                            onChanged: (val) {
                                              _cartNotes[productId] = val;
                                              _lastChangedField = 'product_note_$productId';
                                              _triggerDebouncedAutoSave();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (permDiscountPercent > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'داشکاندنی بەردەوامی کڕیار (${permDiscountPercent.toStringAsFixed(1)}%):',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        '-${Formatters.currency(permDiscountAmount)}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            right: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'داشکان: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _discountType,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'PERCENT',
                                    child: Text('% (ڕێژە)', style: TextStyle(fontSize: 13)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'FIXED',
                                    child: Text('بڕ (پارە)', style: TextStyle(fontSize: 13)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _lastChangedField = 'discount';
                                    setState(() {
                                      _discountType = val;
                                      if (_discountType == 'PERCENT' && _discountValue > 100) {
                                        _discountValue = 100;
                                      }
                                    });
                                    _triggerDebouncedAutoSave();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('discount_field_${_discountValue}_$_discountType'),
                                initialValue: _discountValue == 0 ? '' : _discountValue.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.start,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  hintText: '0',
                                  suffixIcon: _buildFieldStatusIcon('discount'),
                                ),
                                onChanged: (val) {
                                  final parsed = double.tryParse(val) ?? 0.0;
                                  _lastChangedField = 'discount';
                                  setState(() {
                                    _discountValue = parsed;
                                    if (_discountType == 'PERCENT' && _discountValue > 100) {
                                      _discountValue = 100;
                                    }
                                  });
                                  _triggerDebouncedAutoSave();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 52, // Matches AppTextField height exactly
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            left: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'کۆ:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Formatters.currency(totalAmount),
                                textAlign: TextAlign.end,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }


}
