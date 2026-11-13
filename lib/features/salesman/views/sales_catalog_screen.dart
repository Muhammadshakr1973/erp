import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../products/models/category_model.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/views/variant_selector_dialog.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/customer_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../../shared/views/customer_form_dialog.dart';
import '../../shared/views/customer_selection_dialog.dart';

class SalesCatalogScreen extends ConsumerStatefulWidget {
  const SalesCatalogScreen({super.key});

  @override
  ConsumerState<SalesCatalogScreen> createState() => _SalesCatalogScreenState();
}

class _SalesCatalogScreenState extends ConsumerState<SalesCatalogScreen> {
  // Selected Order and Price tier
  OrderModel? _selectedOrder;
  String _selectedPriceTier = 'N3'; // Default 'N3' ('ن٣') as requested
  bool _isManualPriceTierOverride = false;
  Map<int, double> _customerSpecialPrices = {};
  // null override -> defaults to whether category has any product in stock
  final Map<int, bool> _categoryExpandedOverrides = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Local cart map: productId -> quantity in active order
  final Map<int, int> _orderCart = {};
  final Map<int, String> _orderCartNotes = {};

  // 10-second countdown batch sync engine
  Timer? _debounceTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isSavingBatch = false;

  // Track failed actions for persistent retry
  Map<String, dynamic>? _lastFailedBatch;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Sets or switches the currently active order
  void _setActiveOrder(OrderModel? order, {bool isManualOverride = false}) {
    final previousOrderId = _selectedOrder?.id;
    final previousWarehouseId = _selectedOrder?.warehouseId;
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();

    final Map<int, double> initialSpecialPrices = {};
    if (order != null && order.customer is Map) {
      final custMap = order.customer as Map;
      final rawSpecial = custMap['special_prices'] ?? custMap['specialPrices'];
      if (rawSpecial is List) {
        for (final sp in rawSpecial) {
          if (sp is Map) {
            final pid = int.tryParse(sp['product_id']?.toString() ?? '');
            final pr = double.tryParse(sp['price']?.toString() ?? '');
            if (pid != null && pr != null) {
              initialSpecialPrices[pid] = pr;
            }
          }
        }
      }
    }

    setState(() {
      _selectedOrder = order;
      if (order?.warehouseId != previousWarehouseId) {
        _categoryExpandedOverrides.clear();
      }
      _secondsRemaining = 0;
      _orderCart.clear();
      _orderCartNotes.clear();
      if (order == null &&
          _lastFailedBatch?['orderId'] == previousOrderId) {
        _lastFailedBatch = null;
      }
      _isManualPriceTierOverride = isManualOverride;
      _customerSpecialPrices = initialSpecialPrices;

      if (order != null) {
        // Load items from this order
        for (final item in order.items) {
          _orderCart[item.productId] = item.quantity.toInt();
          if (item.notes != null) {
            _orderCartNotes[item.productId] = item.notes!;
          }
        }

        // Set default price tier:
        // By default N3, but if order or customer has a specific price tier, adapt to it
        if (!isManualOverride) {
          if (order.customerId == 0) {
            final orderPriceType = order.priceType?.toUpperCase();
            _selectedPriceTier =
                const ['N1', 'N2', 'N3'].contains(orderPriceType)
                ? orderPriceType!
                : 'N3';
          } else if (order.customer is Map &&
              order.customer['price_type'] != null) {
            _selectedPriceTier = order.customer['price_type']
                .toString()
                .toUpperCase();
          } else if (order.priceType != null &&
              order.priceType!.isNotEmpty &&
              order.priceType != 'SPECIAL') {
            _selectedPriceTier = order.priceType!.toUpperCase();
          } else {
            _selectedPriceTier = 'N3';
          }
        }
        if (!const ['N1', 'N2', 'N3'].contains(_selectedPriceTier)) {
          _selectedPriceTier = 'N3';
        }
      } else {
        _selectedPriceTier = 'N3';
      }
    });

    // Fresh fetch customer special prices if not loaded
    if (order != null && order.customerId > 0) {
      ref
          .read(customerActionsProvider)
          .fetchSpecialPrices(order.customerId)
          .then((prices) {
            if (mounted && _selectedOrder?.id == order.id) {
              setState(() {
                _customerSpecialPrices = prices;
              });
            }
          })
          .catchError((_) {});
    }
  }

  /// Localized name of price tier
  String _tierDisplayName(String tier) {
    switch (tier) {
      case 'N1':
        return 'ن١';
      case 'N2':
        return 'ن٢';
      case 'N3':
      default:
        return 'ن٣';
    }
  }

  /// Calculate unit price for a product according to current price tier or customer special price
  double _getProductPrice(ProductModel product) {
    // If the salesman/cash van manually picked a price tier, it overrides ALL products
    if (_isManualPriceTierOverride) {
      switch (_selectedPriceTier) {
        case 'N1':
          return product.priceN1;
        case 'N2':
          return product.priceN2;
        case 'N3':
        default:
          return product.priceN3;
      }
    }

    // Default / Automatic mode: First check customer special price
    if (_customerSpecialPrices.containsKey(product.id)) {
      final sp = _customerSpecialPrices[product.id]!;
      if (sp > 0) return sp;
    }

    // Otherwise use selected price tier (which is set to customer's tier)
    switch (_selectedPriceTier) {
      case 'N1':
        return product.priceN1;
      case 'N2':
        return product.priceN2;
      case 'N3':
      default:
        return product.priceN3;
    }
  }

  /// Resolves the warehouse ID for sales operations
  int _getTargetWarehouseId() {
    final currentUser = ref.read(authProvider).user;
    final myVanWarehouse = ref.read(myAssignedVanWarehouseProvider);
    final warehouses = ref.read(warehouseListProvider).asData?.value ?? [];
    final defaultWarehouseId = warehouses.where((w) => w.canSell && w.isMain).firstOrNull?.id ??
        warehouses.where((w) => w.canSell).firstOrNull?.id ??
        1;

    return _selectedOrder?.warehouseId ??
        myVanWarehouse?.id ??
        currentUser?.warehouseId ??
        defaultWarehouseId;
  }

  /// Calculates total available stock of product for current active order
  double _getProductAvailableStock(ProductModel product) {
    final targetWarehouseId = _getTargetWarehouseId();
    final double warehouseStock = product.getStockForWarehouse(targetWarehouseId);

    // If active order was already saved with some quantity of this product on the server,
    // that quantity was deducted on the server, so it is part of this order's available pool:
    double savedInThisOrder = 0.0;
    if (_selectedOrder != null) {
      final savedItem = _selectedOrder!.items
          .where((it) => it.productId == product.id)
          .firstOrNull;
      if (savedItem != null) {
        savedInThisOrder = savedItem.quantity;
      }
    }

    return warehouseStock + savedInThisOrder;
  }

  /// Calculates remaining stock after deducting currently selected quantity in this order
  double _getProductRemainingStock(ProductModel product) {
    final totalAvailable = _getProductAvailableStock(product);
    final currentQty = _orderCart[product.id] ?? 0;
    final remaining = totalAvailable - currentQty;
    return remaining < 0 ? 0.0 : remaining;
  }

  /// Increment product quantity in active order
  void _incrementProduct(ProductModel product) {
    if (_selectedOrder == null) {
      _showNoOrderWarning();
      return;
    }

    final totalAvailable = _getProductAvailableStock(product);
    final currentQty = _orderCart[product.id] ?? 0;

    if (totalAvailable <= 0) {
      AppSnackbar.show(
        context,
        message: 'ئەم کاڵایە زیاد نابێت لەبەر ئەوەی لە ستۆک تەواو بووە',
        type: SnackbarType.warning,
      );
      return;
    }

    if (currentQty + 1 > totalAvailable) {
      AppSnackbar.show(
        context,
        message:
            'تەنها ${totalAvailable.toInt()} دانە لە ستۆک بەردەستە و ناتوانی زیاتر زیاد بکەیت',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() {
      _orderCart[product.id] = currentQty + 1;
    });

    _startOrRestart10SecondDebounce(
      actionDesc: 'زیادکردنی ${product.name} بۆ $_selectedOrderCustomerName',
    );
  }

  /// Opens variant selector modal when salesman interacts with a parent product card
  Future<void> _openVariantSelector(
    ProductModel parentProduct,
    List<ProductModel> variants,
  ) async {
    if (_selectedOrder == null) {
      _showNoOrderWarning();
      return;
    }

    if (variants.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'هیچ جۆرێکی چالاک بۆ ئەم کاڵایە بەردەست نییە',
        type: SnackbarType.warning,
      );
      return;
    }

    final initialQuantities = <int, int>{
      for (final v in variants) v.id: _orderCart[v.id] ?? 0,
    };

    final updated = await VariantSelectorDialog.show(
      context,
      parentProduct: parentProduct,
      variants: variants,
      initialQuantities: initialQuantities,
      getPrice: _getProductPrice,
      getAvailableStock: _getProductAvailableStock,
      enforceStockLimit: true,
      initialQuery: _searchQuery,
    );

    if (updated == null || !mounted) return;

    setState(() {
      for (final v in variants) {
        final qty = updated[v.id] ?? 0;
        if (qty > 0) {
          _orderCart[v.id] = qty;
        } else {
          _orderCart.remove(v.id);
          _orderCartNotes.remove(v.id);
        }
      }
    });

    _startOrRestart10SecondDebounce(
      actionDesc:
          'نوێکردنەوەی جۆرەکانی ${parentProduct.name} بۆ $_selectedOrderCustomerName',
    );
  }

  /// Decrement product quantity in active order
  void _decrementProduct(ProductModel product) {
    if (_selectedOrder == null) {
      _showNoOrderWarning();
      return;
    }

    final currentQty = _orderCart[product.id] ?? 0;
    if (currentQty <= 0) return;

    setState(() {
      if (currentQty > 1) {
        _orderCart[product.id] = currentQty - 1;
      } else {
        _orderCart.remove(product.id);
        _orderCartNotes.remove(product.id);
      }
    });

    _startOrRestart10SecondDebounce(
      actionDesc: 'کەمکردنی ${product.name} بۆ $_selectedOrderCustomerName',
    );
  }

  /// Directly edit quantity via fast numeric input dialog
  Future<void> _editQuantityDirectly(ProductModel product) async {
    if (_selectedOrder == null) {
      _showNoOrderWarning();
      return;
    }

    final totalAvailable = _getProductAvailableStock(product);
    if (totalAvailable <= 0) {
      AppSnackbar.show(
        context,
        message: 'ئەم کاڵایە زیاد نابێت لەبەر ئەوەی لە ستۆک تەواو بووە',
        type: SnackbarType.warning,
      );
      return;
    }

    final currentQty = _orderCart[product.id] ?? 0;
    final controller = TextEditingController(text: currentQty.toString());

    final newQty = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top-Left Close Button rule
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Expanded(
                      child: Text(
                        'دیاریکردنی بڕی ${product.name}',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // balance header
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ستۆکی بەردەست: $totalAvailable دانە',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  labelText: 'بڕ (دانە)',
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed != null && parsed >= 0) {
                      if (parsed > totalAvailable) {
                        AppSnackbar.show(
                          ctx,
                          message:
                              'تەنها ${totalAvailable.toInt()} دانە لە ستۆک بەردەستە و ناتوانی زیاتر بنووسیت',
                          type: SnackbarType.warning,
                        );
                        return;
                      }
                      Navigator.pop(ctx, parsed);
                    } else {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text(
                    'جێبەجێکردن',
                    style: TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (newQty != null && mounted) {
      if (newQty > totalAvailable) {
        AppSnackbar.show(
          context,
          message:
              'ناتوانی لە ستۆکی بەردەست ($totalAvailable دانە) زیاتر دیاری بکەیت',
          type: SnackbarType.warning,
        );
        return;
      }

      setState(() {
        if (newQty > 0) {
          _orderCart[product.id] = newQty;
        } else {
          _orderCart.remove(product.id);
          _orderCartNotes.remove(product.id);
        }
      });

      _startOrRestart10SecondDebounce(
        actionDesc:
            'نوێکردنەوەی بڕی ${product.name} بۆ $_selectedOrderCustomerName',
      );
    }
  }

  /// Warn the user if no order is selected
  void _showNoOrderWarning() {
    AppSnackbar.show(
      context,
      message: 'تکایە سەرەتا پسوڵەیەک لە سەرەوە هەڵبژێرە، یان بەتنی (+) دابگرە بۆ دروستکردنی پسوڵەی نوێ!',
      type: SnackbarType.warning,
    );
    _showCreateOrderDialog();
  }

  /// 10-Second Debounce Timer
  void _startOrRestart10SecondDebounce({required String actionDesc}) {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _secondsRemaining = 10;
      });
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });

    _debounceTimer = Timer(const Duration(seconds: 10), () {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _secondsRemaining = 0;
        });
      }
      _executeBatchSave(actionDesc: actionDesc);
    });
  }

  /// Save changes immediately without waiting for 10 seconds
  void _saveImmediately() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _secondsRemaining = 0;
      });
    }
    _executeBatchSave(actionDesc: 'پاشەکەوتکردنی دەستبەجێ');
  }

  /// Executes batch sync to server in a single connection / database transaction
  Future<void> _executeBatchSave({required String actionDesc}) async {
    if (_selectedOrder == null) return;

    final orderId = _selectedOrder!.id;
    final itemsList = <Map<String, dynamic>>[];
    _orderCart.forEach((productId, qty) {
      if (qty > 0) {
        itemsList.add({
          'product_id': productId,
          'quantity': qty,
          'notes': _orderCartNotes[productId],
        });
      }
    });

    final currentUser = ref.read(authProvider).user;
    final myVanWarehouse = ref.read(myAssignedVanWarehouseProvider);
    final targetWarehouseId =
        _selectedOrder!.warehouseId ?? myVanWarehouse?.id ?? currentUser?.warehouseId ?? 1;

    final payload = {
      'customer_id': _selectedOrder!.customerId,
      'warehouse_id': targetWarehouseId,
      'status': _selectedOrder!.status,
      'price_type': _selectedPriceTier,
      'is_manual_price_type': _isManualPriceTierOverride,
      'discount_type': _selectedOrder!.discountType,
      'discount_percent': _selectedOrder!.discountPercent,
      'discount_amount': _selectedOrder!.discountAmount,
      'shared_key': _selectedOrder!.sharedKey,
      'version': _selectedOrder!.version,
      'notes': _selectedOrder!.notes,
      'items': itemsList,
    };

    setState(() {
      _isSavingBatch = true;
    });

    try {
      final updatedOrder = await ref
          .read(orderActionsProvider)
          .updateOrder(orderId, payload);
      if (mounted) {
        final isStillSelected = _selectedOrder?.id == orderId;
        setState(() {
          if (isStillSelected && updatedOrder.id > 0) {
            _selectedOrder = updatedOrder;
            _lastFailedBatch = null;
          }
          _isSavingBatch = false;
        });
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) {
        final isStillSelected = _selectedOrder?.id == orderId;
        setState(() {
          _isSavingBatch = false;
          if (isStillSelected) {
            _lastFailedBatch = {
              'orderId': orderId,
              'customerName': _selectedOrderCustomerName,
              'actionDesc': actionDesc,
              'error': errorMsg,
              'payload': payload,
              'cart': Map<int, int>.from(_orderCart),
            };
          }
        });

        if (isStillSelected) {
          _showFailedActionPersistentDialog();
        }
      }
    }
  }

  /// Persistent Failure Dialog
  void _showFailedActionPersistentDialog() {
    if (_lastFailedBatch == null || !mounted) return;

    final failedInfo = _lastFailedBatch!;
    final customerName = failedInfo['customerName'] ?? 'کڕیار';
    final actionDesc = failedInfo['actionDesc'] ?? 'کرداری کاڵا';
    final errorMsg = failedInfo['error'] ?? 'هەڵەی سێرڤەر';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isRetrying = false;
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final theme = Theme.of(context);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top-Left Close Button rule
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                          tooltip: 'داخستن',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هەڵە لە پاشەکەوتکردنی کاڵا',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Failure description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فەشەل لە ئەنجامدانی: $actionDesc',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'بۆ کڕیار: $customerName',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'هۆکاری هەڵە: $errorMsg',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ئەم کردارە پارێزراوە و نافەوتێت تاوەکو خۆت چارەسەری نەکەیت یان نەیەسڕیتەوە.',
                      style: AppTextStyles.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: isRetrying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text(
                              'دووبارە هەوڵدانەوە',
                              style: TextStyle(
                                fontFamily: 'KJino',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: isRetrying
                                ? null
                                : () async {
                                    setModalState(() => isRetrying = true);
                                    Navigator.pop(dialogCtx);
                                    await _executeBatchSave(
                                      actionDesc: actionDesc,
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text(
                            'سڕینەوەی کردار',
                            style: TextStyle(fontFamily: 'KJino'),
                          ),
                          onPressed: () {
                            setState(() {
                              _lastFailedBatch = null;
                            });
                            Navigator.pop(dialogCtx);
                            AppSnackbar.show(
                              context,
                              message: 'کردارە فەشەلهێناوەکە سڕایەوە',
                              type: SnackbarType.info,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Create New Order Dialog (+)
  Future<void> _showCreateOrderDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top-Left Close Button rule
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'دروستکردنی پسوڵەی نوێ',
                        style: AppTextStyles.h2,
                      ),
                    ),
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 1. Quick Temporary Customer Option
                InkWell(
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    _createOrderForCustomer(Customer.temporary);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flash_on_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'کڕیاری کاتی (بێ ناو)',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'دروستکردنی خێرای پسوڵە؛ دەتوانی دواتر بیگۆڕیت بۆ کڕیاری ڕاستەقینە',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Select Registered Customer Option
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text(
                    'هەڵبژاردنی کڕیار لە لیستەکەدا',
                    style: TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final selectedCust = await CustomerSelectionDialog.show(
                      context,
                    );
                    if (selectedCust != null && mounted) {
                      _createOrderForCustomer(selectedCust);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // 3. Register New Customer Option
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    'تۆمارکردنی کڕیاری نوێ لە سیستەمدا',
                    style: TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final newCust = await showDialog<dynamic>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const CustomerFormDialog(),
                    );
                    if (newCust != null && newCust is Customer && mounted) {
                      _createOrderForCustomer(newCust);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create order for customer and activate it
  Future<void> _createOrderForCustomer(Customer customer) async {
    final warehousesAsync = ref.read(warehouseListProvider);
    final rawWarehouses = warehousesAsync.asData?.value ?? [];
    final warehouses = rawWarehouses.where((w) => w.canSell).toList();

    final myVanWarehouse = ref.read(myAssignedVanWarehouseProvider);
    final int warehouseId =
        myVanWarehouse?.id ??
        (warehouses.any((w) => w.isMain)
            ? warehouses.firstWhere((w) => w.isMain).id
            : (warehouses.isNotEmpty ? warehouses.first.id : 1));

    final String initialPriceTier = customer.priceType?.toUpperCase() ?? 'N3';

    final payload = {
      'customer_id': customer.id,
      'warehouse_id': warehouseId,
      'status': 'PACKING',
      'price_type': initialPriceTier,
      'is_manual_price_type': false,
      'shared_key': 'order_${DateTime.now().microsecondsSinceEpoch}',
      'version': 1,
      'items': [],
    };

    try {
      final newOrder = await ref
          .read(orderActionsProvider)
          .createOrder(payload);
      if (mounted) {
        _setActiveOrder(newOrder);
        AppSnackbar.show(
          context,
          message:
              'پسوڵەی نوێ (${newOrder.orderNumber}) بە سەرکەوتوویی دروستکرا بۆ ${customer.name}',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'هەڵە لە دروستکردنی پسوڵە: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  /// Convert Temporary Customer to a Real Customer
  Future<void> _changeOrderCustomer() async {
    if (_selectedOrder == null) return;

    final selectedCust = await CustomerSelectionDialog.show(context);
    if (selectedCust == null || !mounted) return;

    if (selectedCust.id == 0) {
      AppSnackbar.show(
        context,
        message: 'ئەم پسوڵەیە خۆی بۆ کڕیاری کاتییە',
        type: SnackbarType.warning,
      );
      return;
    }

    final payload = {
      'customer_id': selectedCust.id,
      'warehouse_id': _selectedOrder!.warehouseId,
      'status': 'PACKING',
      'price_type': selectedCust.priceType?.toUpperCase() ?? _selectedPriceTier,
      'is_manual_price_type': false,
      'version': _selectedOrder!.version,
      'items': _orderCart.entries
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList(),
    };

    try {
      final updated = await ref
          .read(orderActionsProvider)
          .updateOrder(_selectedOrder!.id, payload);
      if (mounted) {
        _setActiveOrder(updated);
        AppSnackbar.show(
          context,
          message:
              'کڕیاری پسوڵەکە بە سەرکەوتوویی گۆڕدرا بۆ ${selectedCust.name}',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'هەڵە لە گۆڕینی کڕیار: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  String get _selectedOrderCustomerName {
    if (_selectedOrder == null) return '';
    if (_selectedOrder!.customerId == 0) return 'کڕیاری کاتی';
    if (_selectedOrder!.customer is Map &&
        _selectedOrder!.customer['name'] != null) {
      return _selectedOrder!.customer['name'].toString();
    }
    return 'کڕیار #${_selectedOrder!.customerId}';
  }

  bool get _isSelectedOrderTemporary {
    return _selectedOrder != null &&
        (_selectedOrder!.customerId == 0 ||
            _selectedOrderCustomerName.contains('کاتی'));
  }

  /// Distinct color palette for category frames
  Color _getCategoryColor(int? categoryId, int index, bool isDark) {
    const colors = [
      Color(0xFF2563EB), // Vibrant Blue
      Color(0xFF10B981), // Emerald Green
      Color(0xFF8B5CF6), // Purple
      Color(0xFFF59E0B), // Amber / Gold
      Color(0xFFEC4899), // Rose / Pink
      Color(0xFF06B6D4), // Cyan
      Color(0xFFEF4444), // Coral Red
      Color(0xFF6366F1), // Indigo
      Color(0xFF84CC16), // Lime Green
      Color(0xFFD97706), // Orange
      Color(0xFF14B8A6), // Teal
      Color(0xFFA855F7), // Light Purple
    ];
    if (categoryId == null || categoryId <= 0) {
      return isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }
    final colorIndex = (categoryId * 3 + index) % colors.length;
    return colors[colorIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productsAsync = ref.watch(productsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final ordersAsync = ref.watch(ordersListProvider);
    final authUser = ref.watch(authProvider).user;
    ref.listen<AsyncValue<List<OrderModel>>>(ordersListProvider, (_, next) {
      final selectedOrder = _selectedOrder;
      final refreshedOrders = next.asData?.value;
      if (selectedOrder == null || refreshedOrders == null) return;

      // Only deselect if this order explicitly exists in refreshed list and has been DELIVERED or CANCELLED
      final matchingOrder = refreshedOrders
          .where((order) => order.id == selectedOrder.id)
          .firstOrNull;
      if (matchingOrder != null) {
        final status = matchingOrder.status.toUpperCase();
        if (status == OrderModel.statusDelivered ||
            status == OrderModel.statusCancelled) {
          _setActiveOrder(null);
        }
      }
    });
    final myVanWarehouse = ref.watch(myAssignedVanWarehouseProvider);
    ref.watch(warehouseListProvider);
    final salesWarehouseId =
        authUser?.warehouseId ?? myVanWarehouse?.id;

    // Show available orders in the selector, excluding delivered or cancelled orders.
    final allOrders = ordersAsync.asData?.value ?? [];
    final Map<int, OrderModel> orderMap = {};

    for (final o in allOrders) {
      if (o.id <= 0 || o.orderNumber.isEmpty) continue;
      final status = o.status.toUpperCase();
      final isUnavailable =
          status == OrderModel.statusDelivered ||
          status == OrderModel.statusCancelled;
      if (!isUnavailable) {
        orderMap[o.id] = o;
      }
    }

    // Keep the active order in sync with the latest list snapshot without inserting phantom orders
    if (_selectedOrder != null && _selectedOrder!.id > 0 && _selectedOrder!.orderNumber.isNotEmpty) {
      if (orderMap.containsKey(_selectedOrder!.id)) {
        final matching = orderMap[_selectedOrder!.id]!;
        if ((matching.version != _selectedOrder!.version ||
                matching.status.toUpperCase() !=
                    _selectedOrder!.status.toUpperCase()) &&
            !_isSavingBatch) {
          _selectedOrder = matching;
        }
      } else {
        final status = _selectedOrder!.status.toUpperCase();
        if (status != OrderModel.statusDelivered &&
            status != OrderModel.statusCancelled) {
          orderMap[_selectedOrder!.id] = _selectedOrder!;
        }
      }
    }

    final availableOrders = orderMap.values.toList();
    final allProducts = productsAsync.asData?.value ?? [];
    final categories = categoriesAsync.asData?.value ?? [];
    final categoryMap = {for (final c in categories) c.id: c.name};

    final Map<int, List<ProductModel>> variantsByParent = {};
    for (final p in allProducts) {
      if (p.isActive && p.parentId != null) {
        variantsByParent.putIfAbsent(p.parentId!, () => []).add(p);
      }
    }
    for (final list in variantsByParent.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    // Active top-level products matching search query (including child variant match)
    final displayableProducts = allProducts.where((p) {
      if (!p.isActive || p.isVariant) return false;
      final children = p.isParent
          ? (variantsByParent[p.id] ?? const <ProductModel>[])
          : const <ProductModel>[];
      if (p.isParent && children.isEmpty) return false;

      if (_searchQuery.isNotEmpty) {
        bool matchesItem(ProductModel item) {
          return item.name.toLowerCase().contains(_searchQuery) ||
              (item.variantName != null &&
                  item.variantName!.toLowerCase().contains(_searchQuery)) ||
              item.barcode.toLowerCase().contains(_searchQuery) ||
              (item.sku ?? '').toLowerCase().contains(_searchQuery);
        }

        return matchesItem(p) || children.any(matchesItem);
      }
      return true;
    }).toList();

    // Group products by Category ID
    final Map<int?, List<ProductModel>> groupedByCat = {};
    for (final p in displayableProducts) {
      final normalizedCatId = (p.categoryId != null &&
              p.categoryId! > 0 &&
              (categories.isEmpty || categoryMap.containsKey(p.categoryId)))
          ? p.categoryId
          : null;
      groupedByCat.putIfAbsent(normalizedCatId, () => []).add(p);
    }

    // Sort items within each category alphabetically by Product Name (ناوی کاڵا)
    for (final catId in groupedByCat.keys) {
      groupedByCat[catId]!.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    // Sort category groups by category name (with uncategorized last)
    final sortedCatKeys = groupedByCat.keys.toList()
      ..sort((a, b) {
        if (a == null || a <= 0) return 1;
        if (b == null || b <= 0) return -1;
        final nameA = categoryMap[a] ?? '';
        final nameB = categoryMap[b] ?? '';
        return nameA.compareTo(nameB);
      });

    // Determine whether each category has at least one product available in stock
    final Map<int, bool> categoryHasStockMap = {};
    for (final catId in sortedCatKeys) {
      final productsInGroup = groupedByCat[catId]!;
      bool hasStock = false;
      for (final product in productsInGroup) {
        if (product.isParent) {
          final variants =
              variantsByParent[product.id] ?? const <ProductModel>[];
          if (variants.any((v) => _getProductAvailableStock(v) > 0)) {
            hasStock = true;
            break;
          }
        } else {
          if (_getProductAvailableStock(product) > 0) {
            hasStock = true;
            break;
          }
        }
      }
      categoryHasStockMap[_categoryKey(catId)] = hasStock;
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF13171F)
            : const Color(0xFFF4F6F9),
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP BAR (Matching image 8.png in LTR)
              _buildTopBar(context, availableOrders),

              // 2. 10-SECOND BATCH COUNTDOWN & PERSISTENT FAILURE BAR
              _buildSyncCountdownBanner(context),

              // 3. CATEGORY HEADER & MULTI-SELECT CHECKBOX FILTER BAR
              _buildCategoryBar(
                context,
                categories: categories,
                categoryMap: categoryMap,
                groupedByCat: groupedByCat,
                sortedCatKeys: sortedCatKeys,
                categoryHasStockMap: categoryHasStockMap,
              ),

              // 4. PRODUCT CARDS GRID (Grouped by Category & Collapsible like Dropdowns)
              Expanded(
                child: productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'هەڵە لە هێنانی کاڵاکان: $err',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  data: (_) {
                    if (displayableProducts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'هیچ کاڵایەک نەدۆزرایەوە',
                              style: AppTextStyles.h3,
                            ),
                            if (_searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                },
                                child: const Text(
                                  'سڕینەوەی گەڕان',
                                  style: TextStyle(fontFamily: 'KJino'),
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 600
                            ? 2
                            : constraints.maxWidth < 950
                            ? 3
                            : 4;

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: sortedCatKeys.length,
                          itemBuilder: (context, catIndex) {
                            final catId = sortedCatKeys[catIndex];
                            final productsInGroup = groupedByCat[catId]!;
                            final catName = (catId != null && categoryMap.containsKey(catId))
                                ? categoryMap[catId]!
                                : 'بێ جۆر';
                            final frameColor = _getCategoryColor(catId, catIndex, isDark);
                            final isExpanded = _isCategoryExpanded(catId, categoryHasStockMap);

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: frameColor.withValues(
                                  alpha: isDark ? 0.08 : 0.04,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: frameColor.withValues(
                                    alpha: isDark ? 0.85 : 0.75,
                                  ),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: frameColor.withValues(
                                      alpha: isDark ? 0.18 : 0.1,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Collapsible Category Frame Header
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _toggleCategoryExpanded(
                                          catId,
                                          categoryHasStockMap,
                                        ),
                                        borderRadius: isExpanded
                                            ? const BorderRadius.vertical(
                                                top: Radius.circular(14),
                                              )
                                            : BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: frameColor.withValues(
                                              alpha: isExpanded
                                                  ? (isDark ? 0.24 : 0.14)
                                                  : (isDark ? 0.16 : 0.09),
                                            ),
                                            border: isExpanded
                                                ? Border(
                                                    bottom: BorderSide(
                                                      color: frameColor.withValues(
                                                        alpha: isDark ? 0.45 : 0.35,
                                                      ),
                                                      width: 1.5,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: frameColor.withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.category_rounded,
                                                  size: 18,
                                                  color: frameColor,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  catName,
                                                  style: TextStyle(
                                                    fontFamily: 'KJino',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: frameColor,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${productsInGroup.length} کاڵا',
                                                  style: const TextStyle(
                                                    fontFamily: 'KJino',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              AnimatedRotation(
                                                turns: isExpanded ? 0.5 : 0.0,
                                                duration: const Duration(milliseconds: 220),
                                                curve: Curves.easeInOut,
                                                child: Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  size: 22,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Product Grid inside category frame (collapses when unchecked/closed)
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeInOut,
                                      alignment: Alignment.topCenter,
                                      child: isExpanded
                                          ? Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: GridView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: crossAxisCount,
                                                  childAspectRatio: 0.68,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                ),
                                                itemCount: productsInGroup.length,
                                                itemBuilder: (context, index) {
                                                  final product = productsInGroup[index];
                                                  final variants = product.isParent
                                                      ? (variantsByParent[product.id] ?? const <ProductModel>[])
                                                      : const <ProductModel>[];
                                                  final qtyInCart = product.isParent
                                                      ? variants.fold<int>(0, (sum, v) => sum + (_orderCart[v.id] ?? 0))
                                                      : (_orderCart[product.id] ?? 0);
                                                  return _buildProductCard(
                                                    context,
                                                    key: ValueKey(product.id),
                                                    product: product,
                                                    variants: variants,
                                                    quantity: qtyInCart,
                                                    user: authUser,
                                                    warehouseId: salesWarehouseId,
                                                  );
                                                },
                                              ),
                                            )
                                          : const SizedBox(
                                              width: double.infinity,
                                              height: 0,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Bar matching design in 8.png
  Future<void> _openSelectedOrder() async {
    final order = _selectedOrder;
    if (order == null) return;

    await context.push('/order/${order.id}');
    if (!mounted || _selectedOrder?.id != order.id) return;

    final updatedOrder = ref
        .read(ordersListProvider)
        .valueOrNull
        ?.where((current) => current.id == order.id)
        .firstOrNull;
    if (updatedOrder?.status.toUpperCase() == OrderModel.statusDelivered) {
      _setActiveOrder(null);
    }
  }

  Widget _buildTopBar(BuildContext context, List<OrderModel> availableOrders) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF2E3846)
                : theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Open the selected order in its detail view
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3442) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              tooltip: 'کردنەوەی پسوڵە',
              onPressed: _selectedOrder == null ? null : _openSelectedOrder,
            ),
          ),
          const SizedBox(width: 6),

          // Price Tier Dropdown: ن١, ن٢, ن٣
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3442) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: const ['N1', 'N2', 'N3'].contains(_selectedPriceTier)
                    ? _selectedPriceTier
                    : 'N3',
                dropdownColor: isDark ? const Color(0xFF2A3442) : Colors.white,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                style: const TextStyle(
                  fontFamily: 'KJino',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                items: const [
                  DropdownMenuItem(value: 'N1', child: Text('ن١')),
                  DropdownMenuItem(value: 'N2', child: Text('ن٢')),
                  DropdownMenuItem(value: 'N3', child: Text('ن٣')),
                ],
                onChanged: (newTier) {
                  if (newTier != null) {
                    setState(() {
                      _selectedPriceTier = newTier;
                      _isManualPriceTierOverride = true;
                    });

                    // ئەگەر پسوڵە هەڵبژێردرابێت، دەستبەجێ باکێند نوێ بکەرەوە بۆ ئەم جۆری نرخە تا هەموو کاڵاکانی پسوڵەکە بەو نرخە بن
                    if (_selectedOrder != null) {
                      _startOrRestart10SecondDebounce(
                        actionDesc: 'گۆڕینی جۆری نرخ بۆ ${_tierDisplayName(newTier)} بۆ $_selectedOrderCustomerName',
                      );
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Order Selection Dropdown
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A3442) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value:
                      (_selectedOrder != null &&
                          _selectedOrder!.id > 0 &&
                          availableOrders.any(
                            (o) => o.id == _selectedOrder!.id,
                          ))
                      ? _selectedOrder!.id
                      : null,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF2A3442)
                      : Colors.white,
                  hint: Text(
                    'پسوڵەیەک هەڵبژێرە',
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'هیچ پسوڵەیەک هەڵنەبژێردراوە',
                        style: TextStyle(fontFamily: 'KJino', fontSize: 12),
                      ),
                    ),
                    ...availableOrders
                        .where((o) => o.id > 0 && o.orderNumber.isNotEmpty)
                        .map((order) {
                      final custName =
                          (order.customer is Map &&
                              order.customer['name'] != null)
                          ? order.customer['name'].toString()
                          : (order.customerId == 0
                                ? 'کڕیاری کاتی (بێ ناو)'
                                : 'کڕیار #${order.customerId}');
                      return DropdownMenuItem<int?>(
                        value: order.id,
                        child: Text(
                          '\u202A${order.orderNumber}\u202C • $custName',
                          style: const TextStyle(
                            fontFamily: 'KJino',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (orderId) {
                    if (orderId == null) {
                      _setActiveOrder(null);
                    } else {
                      final ord = availableOrders
                          .where((o) => o.id == orderId)
                          .firstOrNull;
                      _setActiveOrder(ord);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // (+) Button next to dropdown for creating order
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.add, color: Colors.white, size: 22),
              tooltip: 'دروستکردنی پسوڵەی نوێ',
              onPressed: _showCreateOrderDialog,
            ),
          ),
          const SizedBox(width: 6),

          // If current order is temporary, show quick convert icon
          if (_isSelectedOrderTemporary)
            IconButton(
              icon: const Icon(
                Icons.person_pin_rounded,
                color: Colors.amber,
                size: 22,
              ),
              tooltip: 'گۆڕینی کڕیاری کاتی بۆ کڕیاری ڕاستەقینە',
              onPressed: _changeOrderCustomer,
            ),

          // Logo image only (no text)
          Image.asset('assets/images/1.png', height: 36, fit: BoxFit.contain),
        ],
      ),
    );
  }

  /// 10-Second Countdown & Sync Status Banner
  Widget _buildSyncCountdownBanner(BuildContext context) {
    const double bannerHeight = 36.0;

    if (_lastFailedBatch != null) {
      return Container(
        height: bannerHeight,
        color: AppColors.danger.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'فەشەل لە پاشەکەوتکردنی کاڵاکان بۆ ${_lastFailedBatch!['customerName']}',
                style: const TextStyle(
                  fontFamily: 'KJino',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.danger,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _showFailedActionPersistentDialog,
              child: const Text(
                'چارەسەرکردن',
                style: TextStyle(
                  fontFamily: 'KJino',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  int _categoryKey(int? categoryId) =>
      (categoryId != null && categoryId > 0) ? categoryId : -1;

  bool _isCategoryExpanded(
    int? categoryId,
    Map<int, bool> categoryHasStockMap,
  ) {
    final key = _categoryKey(categoryId);
    return _categoryExpandedOverrides[key] ?? (categoryHasStockMap[key] ?? true);
  }

  void _toggleCategoryExpanded(
    int? categoryId,
    Map<int, bool> categoryHasStockMap,
  ) {
    final key = _categoryKey(categoryId);
    final currentExpanded = _isCategoryExpanded(categoryId, categoryHasStockMap);
    setState(() {
      _categoryExpandedOverrides[key] = !currentExpanded;
    });
  }

  /// Category Header & Multi-Select Checkbox Filters (excluding empty categories)
  Widget _buildCategoryBar(
    BuildContext context, {
    required List<CategoryModel> categories,
    required Map<int, String> categoryMap,
    required Map<int?, List<ProductModel>> groupedByCat,
    required List<int?> sortedCatKeys,
    required Map<int, bool> categoryHasStockMap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Only include categories that have at least one product
    final nonEmptyCategories = categories
        .where((cat) => (groupedByCat[cat.id]?.isNotEmpty ?? false))
        .toList();
    final bool hasUncategorized = groupedByCat[null]?.isNotEmpty ?? false;

    final visibleCategoryKeys = sortedCatKeys.map(_categoryKey).toList();
    final bool allChecked = visibleCategoryKeys.isNotEmpty &&
        visibleCategoryKeys.every(
          (k) => _categoryExpandedOverrides[k] ?? (categoryHasStockMap[k] ?? true),
        );
    final int checkedCatCount = visibleCategoryKeys
        .where(
          (k) => _categoryExpandedOverrides[k] ?? (categoryHasStockMap[k] ?? true),
        )
        .length;

    int itemCount = 0;
    for (final catId in sortedCatKeys) {
      if (_isCategoryExpanded(catId, categoryHasStockMap)) {
        itemCount += groupedByCat[catId]?.length ?? 0;
      }
    }

    String currentCategoryName = 'هەموو کاڵاکان';
    if (sortedCatKeys.isNotEmpty && !allChecked) {
      if (checkedCatCount == 0) {
        currentCategoryName = 'هیچ کاتیگۆریەک دیاری نەکراوە';
      } else if (checkedCatCount == 1) {
        final activeCatId = sortedCatKeys.firstWhere(
          (catId) => _isCategoryExpanded(catId, categoryHasStockMap),
          orElse: () => null,
        );
        currentCategoryName =
            (activeCatId != null && categoryMap.containsKey(activeCatId))
                ? categoryMap[activeCatId]!
                : 'بێ جۆر';
      } else {
        currentCategoryName = '$checkedCatCount کاتیگۆری دیاریکراو';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19202B) : Colors.grey.shade100,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isSavingBatch)
                Tooltip(
                  message: 'پاشەکەوتکردن بە یەک کۆنێکشن لە داتابەیس...',
                  child: Container(
                    width: 54,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'item $itemCount',
                    style: TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (_secondsRemaining > 0 &&
                  _lastFailedBatch == null &&
                  !_isSavingBatch)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_secondsRemaining چرکە',
                      style: const TextStyle(
                        fontFamily: 'KJino',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _saveImmediately,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ئێستا پاشەکەوت بکە',
                          style: TextStyle(
                            fontFamily: 'KJino',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Flexible(
                  child: Text(
                    currentCategoryName,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Horizontal category checkbox filters (non-empty categories only)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (visibleCategoryKeys.isNotEmpty)
                  _buildCategoryCheckboxChip(
                    context,
                    label: 'هەموو',
                    isChecked: allChecked,
                    onTap: () {
                      setState(() {
                        final targetValue = !allChecked;
                        for (final k in visibleCategoryKeys) {
                          _categoryExpandedOverrides[k] = targetValue;
                        }
                      });
                    },
                  ),
                ...nonEmptyCategories.map((cat) {
                  return _buildCategoryCheckboxChip(
                    context,
                    label: cat.name,
                    isChecked: _isCategoryExpanded(cat.id, categoryHasStockMap),
                    onTap: () => _toggleCategoryExpanded(cat.id, categoryHasStockMap),
                  );
                }),
                if (hasUncategorized)
                  _buildCategoryCheckboxChip(
                    context,
                    label: 'بێ جۆر',
                    isChecked: _isCategoryExpanded(null, categoryHasStockMap),
                    onTap: () => _toggleCategoryExpanded(null, categoryHasStockMap),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCheckboxChip(
    BuildContext context, {
    required String label,
    required bool isChecked,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isChecked
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF242C38) : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isChecked
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF3A4659) : Colors.grey.shade300),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isChecked
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.grey.shade500),
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'KJino',
                    fontSize: 11,
                    fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                    color: isChecked
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Product Card matching image 8.png
  Widget _buildProductCard(
    BuildContext context, {
    required Key key,
    required ProductModel product,
    List<ProductModel> variants = const [],
    required int quantity,
    required dynamic user,
    required int? warehouseId,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isParentCard = product.isParent && variants.isNotEmpty;

    double unitPrice = _getProductPrice(product);
    double? minVariantPrice;
    double? maxVariantPrice;
    if (isParentCard) {
      final prices = variants.map(_getProductPrice).toList();
      prices.sort();
      minVariantPrice = prices.first;
      maxVariantPrice = prices.last;
      unitPrice = minVariantPrice;
    }

    // Stock calculation
    final double totalAvailable = isParentCard
        ? variants.fold<double>(0.0, (s, v) => s + _getProductAvailableStock(v))
        : _getProductAvailableStock(product);
    final double remainingStock = isParentCard
        ? variants.fold<double>(0.0, (s, v) => s + _getProductRemainingStock(v))
        : _getProductRemainingStock(product);
    final bool isOutOfStock = totalAvailable <= 0;
    final bool isLimitReached = remainingStock <= 0;
    final bool canIncrement = remainingStock > 0;
    final bool canDecrement = quantity > 0;
    final bool isInSelectedOrder = _selectedOrder != null && quantity > 0;

    // Visual inactive look when in selected order or out of stock, while remaining interactive
    final bool isStockDepleted = isOutOfStock || isLimitReached;
    final double cardOpacity = isStockDepleted
        ? 0.50
        : (isInSelectedOrder ? 0.60 : 1.0);

    final Color borderColor = isStockDepleted
        ? (isDark ? const Color(0xFFFE3F30) : const Color(0xFFE53935))
        : (isInSelectedOrder
            ? (isDark ? const Color(0xFF00E676) : const Color(0xFF10B981))
            : (quantity > 0
                ? AppColors.primary
                : (isDark ? const Color(0xFF333E4F) : Colors.grey.shade300)));

    final double borderWidth = (isStockDepleted || isInSelectedOrder)
        ? 2.5
        : (quantity > 0 ? 1.5 : 1.0);

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242C38) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          if (isStockDepleted)
            BoxShadow(
              color: (isDark ? const Color(0xFFFE3F30) : const Color(0xFFE53935))
                  .withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          else if (isInSelectedOrder)
            BoxShadow(
              color: (isDark ? const Color(0xFF00E676) : const Color(0xFF10B981))
                  .withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. PRODUCT IMAGE
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (product.imagePath != null && product.imagePath!.isNotEmpty)
                        ? Image.network(
                            product.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderImage(),
                          )
                        : _buildPlaceholderImage(),

                    // In-order badge at top-left
                    if (isInSelectedOrder)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF0A9C6E))
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'لە پسوڵەدایە',
                                style: TextStyle(
                                  fontFamily: 'KJino',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Variant count badge at bottom-right
                    if (isParentCard)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.layers_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${variants.length} جۆر',
                                style: const TextStyle(
                                  fontFamily: 'KJino',
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Stock badge at top-right
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isOutOfStock || isLimitReached)
                              ? const Color(0xFFB71C1C).withValues(alpha: 0.85)
                              : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: (isOutOfStock || isLimitReached)
                              ? Border.all(color: Colors.red.shade400, width: 0.8)
                              : null,
                        ),
                        child: Text(
                          'ستۆک: ${remainingStock.toInt()}',
                          style: const TextStyle(
                            fontFamily: 'KJino',
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. PRODUCT NAME & PRICE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 13,
                      fontFamily: 'KJino',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          (isParentCard &&
                                  minVariantPrice != null &&
                                  maxVariantPrice != null &&
                                  minVariantPrice != maxVariantPrice)
                              ? '${Formatters.currency(minVariantPrice)} - ${Formatters.currency(maxVariantPrice)}'
                              : Formatters.currency(unitPrice),
                          style: TextStyle(
                            fontFamily: 'KJino',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isParentCard &&
                          !_isManualPriceTierOverride &&
                          _customerSpecialPrices.containsKey(product.id)) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.shade700,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'تایبەت',
                            style: TextStyle(
                              fontFamily: 'KJino',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 3. QUANTITY COUNTER BAR (Matching 8.png: [-] [ 0 ] [+])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B212B) : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  // [-] Red Button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canDecrement
                            ? const Color(0xFFE53935)
                            : (isDark ? const Color(0xFF2E3846) : Colors.grey.shade300),
                        foregroundColor: canDecrement
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.grey.shade500),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: canDecrement
                          ? () => isParentCard
                              ? _openVariantSelector(product, variants)
                              : _decrementProduct(product)
                          : null,
                      child: const Icon(Icons.remove, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Center Quantity Box (Tap to type custom number)
                  Expanded(
                    child: InkWell(
                      onTap: isParentCard
                          ? () => _openVariantSelector(product, variants)
                          : (isOutOfStock
                              ? () {
                                  AppSnackbar.show(
                                    context,
                                    message: 'ئەم کاڵایە لە ستۆک بەردەست نییە',
                                    type: SnackbarType.warning,
                                  );
                                }
                              : () => _editQuantityDirectly(product)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E3846)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF435064)
                                : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: TextStyle(
                            fontFamily: 'KJino',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: quantity > 0
                                ? (isDark ? Colors.white : AppColors.primary)
                                : (isDark ? Colors.white54 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // [+] Green Button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canIncrement
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF2E3846) : Colors.grey.shade300),
                        foregroundColor: canIncrement
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.grey.shade500),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: canIncrement
                          ? () => isParentCard
                              ? _openVariantSelector(product, variants)
                              : _incrementProduct(product)
                          : (isParentCard && quantity > 0
                              ? () => _openVariantSelector(product, variants)
                              : null),
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
      ),
    );
  }
}
