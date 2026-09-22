import 'dart:async';
import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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

  int _getCartTotalCount() {
    return _cart.values.fold(0, (sum, qty) => sum + qty);
  }

  void _addToCart(int productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
    _triggerAutoSave();
  }

  void _removeFromCart(int productId) {
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
    _triggerAutoSave();
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
      _triggerAutoSave();
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
      setState(() {
        _cart[productId] = newQty;
      });
      _triggerAutoSave();
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

  Future<void> _submitOrder(
    List<ProductModel> products,
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) async {
    if (warehousesAsync.hasError || warehousesAsync.asData == null) {
      AppSnackbar.show(
        context,
        message: 'هەڵە لە بارکردنی کۆگاکان (Failed to load warehouses)',
        type: SnackbarType.error,
      );
      return;
    }

    final warehouses = warehousesAsync.asData!.value;
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'هیچ کۆگایەک بەردەست نییە بۆ دروستکردنی پسوڵە',
        type: SnackbarType.error,
      );
      return;
    }

    if (_selectedCustomer == null) {
      AppSnackbar.show(
        context,
        message: 'تکایە سەرەتا کڕیارێک هەڵبژێرە',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_cart.isEmpty && widget.existingOrder == null) {
      AppSnackbar.show(
        context,
        message: 'سەبەتە بەتاڵە! کاڵا بنێرە ناو سەبەتە',
        type: SnackbarType.warning,
      );
      return;
    }

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

    final String sharedKey = widget.existingOrder?.sharedKey ??
        'order_${DateTime.now().microsecondsSinceEpoch}';
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

    setState(() => _isSubmitting = true);

    try {
      if (widget.existingOrder != null) {
        await ref
            .read(orderActionsProvider)
            .updateOrder(widget.existingOrder!.id, payload);
      } else {
        await ref.read(orderActionsProvider).createOrder(payload);
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: widget.existingOrder != null
              ? 'پسوڵەکە بە سەرکەوتوویی نوێکرایەوە'
              : 'پسوڵەکە بە سەرکەوتوویی دروستکرا',
          type: SnackbarType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'هەڵە لە تۆمارکردنی پسوڵە: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _autoSaveOrder(
    List<ProductModel> products,
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) async {
    if (widget.existingOrder == null) return;
    if (warehousesAsync.hasError || warehousesAsync.asData == null) return;

    final warehouses = warehousesAsync.asData!.value;
    if (warehouses.isEmpty) return;
    if (_selectedCustomer == null) return;

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

    final String? sharedKey = widget.existingOrder!.sharedKey;
    final int version = widget.existingOrder!.version;

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

    try {
      await ref
          .read(orderActionsProvider)
          .updateOrder(widget.existingOrder!.id, payload);
    } catch (_) {}
  }

  void _triggerAutoSave() {
    final productsAsync = ref.read(productsListProvider);
    final warehousesAsync = ref.read(warehouseListProvider);
    if (productsAsync.asData != null && warehousesAsync.asData != null) {
      _autoSaveOrder(productsAsync.asData!.value, warehousesAsync);
    }
  }

  void _triggerDebouncedAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _triggerAutoSave();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'orders.create',
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final customersAsync = ref.watch(customerListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    final allProducts = productsAsync.asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOrder != null ? 'دەستکاری پسوڵە' : 'پسوڵەی نوێ', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            tooltip: 'سکانی باڕکۆد',
            onPressed: () => _scanBarcode(allProducts),
          ),
        ],
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
                              allProducts,
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            flex: 1,
                            child: _buildCartPanel(allProducts, warehousesAsync),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _buildProductAutocompleteInput(
                              allProducts,
                              productsAsync.isLoading,
                            ),
                          ),
                          if (productsAsync.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: LinearProgressIndicator(),
                            ),
                          Expanded(
                            child: _buildCartPanel(allProducts, warehousesAsync),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: customersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => const Text('هەڵە لە بارکردنی کڕیاران'),
                  data: (customers) {
                    return DropdownButtonFormField<int>(
                      key: ValueKey(_selectedCustomer?.id),
                      initialValue: customers.any((c) => c.id == _selectedCustomer?.id)
                          ? _selectedCustomer?.id
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'دیاریکردنی کڕیار',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: customers.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.priceType ?? 'N2'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final found = customers
                            .where((c) => c.id == val)
                            .firstOrNull;
                        setState(() {
                          _selectedCustomer = found;
                        });
                        if (found != null) {
                          _fetchSpecialPricesForCustomer(found.id);
                        }
                      },
                    );
                  },
                ),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    'نرخی ${_selectedCustomer!.priceType ?? 'N2'}',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          warehousesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'هەڵە لە بارکردنی کۆگاکان (Failed to load warehouses)',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppColors.danger),
                    onPressed: () => ref.refresh(warehouseListProvider),
                  ),
                ],
              ),
            ),
            data: (warehouses) {
              if (warehouses.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                      SizedBox(width: AppSpacing.xs),
                      Text('هیچ کۆگایەک بەردەست نییە'),
                    ],
                  ),
                );
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
                decoration: const InputDecoration(
                  labelText: 'دیاریکردنی کۆگا',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: warehouses.map((w) {
                  return DropdownMenuItem<int>(
                    value: w.id,
                    child: Text(
                      '${w.name}${w.isMain ? " (سەرەکی)" : ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedWarehouseId = val;
                    });
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelectionSection(
    AsyncValue<List<ProductModel>> productsAsync,
    List<ProductModel> allProducts,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _buildProductAutocompleteInput(
            allProducts,
            productsAsync.isLoading,
          ),
        ),
        if (productsAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
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
                      'لە ڕێگەی ئینپوتی سەرەوە بە ناوی کاڵا یان باڕکۆد بگەڕێ بۆ ئەوەی ڕاستەوخۆ کاڵا زیادبکەیت بۆ پسوڵەکە',
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
    bool isLoading,
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

            return AppTextField(
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
            );
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<ProductModel> onSelected,
        Iterable<ProductModel> options,
      ) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color: theme.colorScheme.surface,
              child: SizedBox(
                width: _searchFieldWidth ?? 450,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 22,
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
                                        if (product.sku != null &&
                                            product.sku!.isNotEmpty)
                                          Text(
                                            'SKU: ${product.sku}',
                                            style: AppTextStyles.caption,
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
    AsyncValue<List<WarehouseModel>> warehousesAsync,
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
    final cartItemCount = _getCartTotalCount();

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سەبەتە', style: AppTextStyles.h2),
                Chip(
                  label: Text('$cartItemCount کاڵا'),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
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
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final productId = _cart.keys.elementAt(index);
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
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.3),
                                width: isSpecialPrice ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: isSpecialPrice
                                  ? AppColors.primary.withValues(alpha: 0.05)
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
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'نرخی تایبەت',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                '${Formatters.currency(unitPrice)} / ${product?.unit ?? "دانە"}',
                                                style: AppTextStyles.caption.copyWith(
                                                  color: isSpecialPrice
                                                      ? AppColors.primary
                                                      : null,
                                                  fontWeight: isSpecialPrice
                                                      ? FontWeight.bold
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'کۆ: ${Formatters.currency(unitPrice * qty)}',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'کلیک: دانانی نرخی تایبەت | دەستگرتن: سڕینەوە',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context).hintColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: AppColors.danger,
                                          ),
                                          onPressed: () =>
                                              _removeFromCart(productId),
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
                                            child: Text(
                                              '$qty',
                                              style: AppTextStyles.bodyBold
                                                  .copyWith(
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: AppColors.primary,
                                          ),
                                          onPressed: () => _addToCart(productId),
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
                                        decoration: const InputDecoration(
                                          hintText: 'تێبینی بۆ ئەم کاڵایە...',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (val) {
                                          _cartNotes[productId] = val;
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
                Row(
                  children: [
                    const Text('داشکاندن: '),
                    const SizedBox(width: AppSpacing.sm),
                    DropdownButton<String>(
                      value: _discountType,
                      items: const [
                        DropdownMenuItem(value: 'PERCENT', child: Text('% (ڕێژە)')),
                        DropdownMenuItem(value: 'FIXED', child: Text('بڕ (پارە)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _discountType = val;
                            if (_discountType == 'PERCENT' && _discountValue > 100) {
                              _discountValue = 100;
                            }
                          });
                          _triggerAutoSave();
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        initialValue: _discountValue.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
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
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _notesController,
                  hintText: 'تێبینی (ئارەزوومەندانە)...',
                  onChanged: (val) {
                    _triggerDebouncedAutoSave();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆ کۆتایی:', style: AppTextStyles.bodyLarge),
                    Text(
                      Formatters.currency(totalAmount),
                      style: AppTextStyles.priceLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  width: double.infinity,
                  text: 'تەواوکردنی پسوڵە',
                  isLoading: _isSubmitting,
                  onPressed: (_cart.isNotEmpty && !warehousesAsync.hasError)
                      ? () => _submitOrder(allProducts, warehousesAsync)
                      : null,
                  size: AppButtonSize.lg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}
