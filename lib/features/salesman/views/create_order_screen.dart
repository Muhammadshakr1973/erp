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
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/pusher_service.dart';

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
  Map<int, double> _customerSpecialPrices =
      {}; // product_id -> special unit price
  String _discountType = 'FIXED';
  double _discountValue = 0.0;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double? _searchFieldWidth;
  final GlobalKey _searchKey = GlobalKey();

  int? _serverOrderId;
  String? _sharedKey;
  int _currentVersion = 1;
  int? _subscribedOrderId;
  PusherService? _pusherService;
  bool _hasSavedOnce = false;
  bool _isSaving = false;

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _timerPausedForRetry = false;
  int _failureCount = 0;

  String? _lastChangedField;
  final Map<String, String> _fieldStates =
      {}; // field_name -> 'saving' | 'success' | 'error'
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
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
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
    _pusherService = ref.read(pusherServiceProvider);
    _sharedKey = 'order_${DateTime.now().microsecondsSinceEpoch}';
    _currentVersion = widget.existingOrder?.version ?? 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.existingOrder != null) {
        _populateFromExistingOrder(widget.existingOrder!);
      } else if (widget.preselectedCustomerId != null) {
        _loadPreselectedCustomer();
      }
    });
  }

  void _populateFromExistingOrder(OrderModel order) {
    setState(() {
      _serverOrderId = order.id;
      _sharedKey = order.sharedKey;
      _currentVersion = order.version;
      _hasSavedOnce = true;
      _selectedWarehouseId = order.warehouseId;
      _discountType = (order.discountPercent == 0 && order.discountAmount == 0)
          ? 'FIXED'
          : order.discountType;
      _discountValue = _discountType == 'PERCENT'
          ? order.discountPercent
          : order.discountAmount;
      if (order.notes != null) {
        _notesController.text = order.notes!;
      } else {
        _notesController.clear();
      }
      _cart.clear();
      _cartNotes.clear();
      for (var item in order.items) {
        _cart[item.productId] = item.quantity.toInt();
        if (item.notes != null) {
          _cartNotes[item.productId] = item.notes!;
        }
      }

      // Clear all local error and saving states since we populated the pristine server-state!
      _fieldStates.removeWhere(
        (key, value) =>
            key.startsWith('product_qty_') ||
            key.startsWith('product_note_') ||
            key == 'customer' ||
            key == 'warehouse' ||
            key == 'discount' ||
            key == 'order_notes',
      );
      _fieldErrors.removeWhere(
        (key, value) =>
            key.startsWith('product_qty_') ||
            key.startsWith('product_note_') ||
            key == 'customer' ||
            key == 'warehouse' ||
            key == 'discount' ||
            key == 'order_notes',
      );
    });
    _subscribeToOrderPusher(order.id);
    _loadCustomerById(order.customerId);
  }

  void _subscribeToOrderPusher(int orderId) {
    if (_subscribedOrderId == orderId) return;
    _unsubscribeFromOrderPusher();

    final pusher = (_pusherService ?? ref.read(pusherServiceProvider))!;
    _pusherService ??= pusher;
    _subscribedOrderId = orderId;
    pusher.subscribeToOrder(orderId, _onRemoteOrderUpdate);
    debugPrint(
      "CreateOrderScreen: Subscribed to Pusher updates for order $orderId",
    );
  }

  void _unsubscribeFromOrderPusher() {
    if (_subscribedOrderId == null) return;

    final pusher = _pusherService;
    final orderId = _subscribedOrderId;
    if (pusher != null && orderId != null) {
      pusher.unsubscribeFromOrder(orderId, _onRemoteOrderUpdate);
      debugPrint(
        "CreateOrderScreen: Unsubscribed from Pusher updates for order $orderId",
      );
    }
    _subscribedOrderId = null;
  }

  void _onRemoteOrderUpdate(Map<String, dynamic> eventData) async {
    debugPrint("CreateOrderScreen: Received Pusher event: $eventData");
    if (!mounted || _isSaving) return;

    // Support both flat and nested 'data' wrappers from Laravel/Pusher
    final dynamic dataObj =
        eventData.containsKey('data') && eventData['data'] is Map
        ? eventData['data']
        : eventData;

    final dynamic rawVersion = dataObj['version'];
    final int? eventVersion = rawVersion is num
        ? rawVersion.toInt()
        : (rawVersion != null ? int.tryParse(rawVersion.toString()) : null);

    if (eventVersion != null && eventVersion > _currentVersion) {
      try {
        debugPrint(
          "CreateOrderScreen: Event version ($eventVersion) > current local version ($_currentVersion). Refreshing order...",
        );
        final latestOrder = await ref.refresh(
          singleOrderProvider(_subscribedOrderId!.toString()).future,
        );
        if (latestOrder != null && mounted) {
          _populateFromExistingOrder(latestOrder);
          AppSnackbar.show(
            context,
            message: 'پسوڵەکە لە لایەن ئامێرێکی ترەوە نوێکرایەوە',
            type: SnackbarType.info,
          );
        }
      } catch (e) {
        debugPrint("CreateOrderScreen: Error fetching updated order: $e");
      }
    } else {
      debugPrint(
        "CreateOrderScreen: Ignored older or duplicate version event (eventVersion: $eventVersion, localVersion: $_currentVersion)",
      );
    }
  }

  void _loadCustomerById(int customerId) async {
    if (customerId <= 0) return;
    try {
      final customers = await ref.read(customerListProvider.future);
      final match = customers.where((c) => c.id == customerId).firstOrNull;
      if (match != null && mounted) {
        setState(() {
          _selectedCustomer = match;
        });
        _fetchSpecialPricesForCustomer(match.id);
        return;
      }
    } catch (_) {}

    // Fallback: load directly using singleCustomerProvider
    try {
      final customer = await ref.read(
        singleCustomerProvider(customerId).future,
      );
      if (mounted) {
        setState(() {
          _selectedCustomer = customer;
        });
        _fetchSpecialPricesForCustomer(customer.id);
      }
    } catch (e) {
      debugPrint("CreateOrderScreen: Error loading customer $customerId: $e");
    }
  }

  void _loadPreselectedCustomer() async {
    final customerId = widget.preselectedCustomerId;
    if (customerId == null || customerId <= 0) return;
    try {
      final customers = await ref.read(customerListProvider.future);
      final match = customers.where((c) => c.id == customerId).firstOrNull;
      if (match != null && mounted) {
        setState(() {
          _selectedCustomer = match;
        });
        _fetchSpecialPricesForCustomer(match.id);
        return;
      }
    } catch (_) {}

    // Fallback: load directly using singleCustomerProvider
    try {
      final customer = await ref.read(
        singleCustomerProvider(customerId).future,
      );
      if (mounted) {
        setState(() {
          _selectedCustomer = customer;
        });
        _fetchSpecialPricesForCustomer(customer.id);
      }
    } catch (e) {
      debugPrint(
        "CreateOrderScreen: Error loading preselected customer $customerId: $e",
      );
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

  Future<void> _handleRefresh() async {
    ref.invalidate(productsListProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(warehouseListProvider);
    if (_selectedCustomer != null) {
      await _fetchSpecialPricesForCustomer(_selectedCustomer!.id);
    }
    try {
      await Future.wait([
        ref.read(productsListProvider.notifier).fetchProducts(),
        ref.read(customerListProvider.future),
        ref.read(warehouseListProvider.future),
      ]);
    } catch (_) {}
  }

  @override
  void dispose() {
    _unsubscribeFromOrderPusher();
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
        content: AppTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          labelText: 'بڕ (دانە)',
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
                  Text('کاڵا: ${product.name}', style: AppTextStyles.bodyBold),
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
                  AppTextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    labelText: 'نرخی تایبەتی نوێ (دینار)',
                    prefixIcon: Icons.monetization_on_outlined,
                  ),
                ],
              ),
            ),
            actions: [
              if (hasSpecial)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
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
                                message: 'نرخی تایبەت سڕایەوە و گەڕایەوە بۆ نرخی بنەڕەتی',
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
                            if (modalCtx.mounted)
                              setDialogState(() => isSaving = false);
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
                          if (modalCtx.mounted)
                            setDialogState(() => isSaving = false);
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
    AsyncValue<List<WarehouseModel>> warehousesAsync, {
    List<Map<String, dynamic>>? customItems,
  }) async {
    if (warehousesAsync.hasError || warehousesAsync.asData == null) return;

    final warehouses = warehousesAsync.asData!.value;
    if (warehouses.isEmpty) return;
    if (_selectedCustomer == null) return;
    if (widget.existingOrder == null && _cart.isEmpty) return;

    final warehouseId =
        _selectedWarehouseId ??
        (warehouses.any((w) => w.isMain)
            ? warehouses.firstWhere((w) => w.isMain).id
            : warehouses.first.id);

    final List<Map<String, dynamic>> itemsList = [];
    if (customItems != null) {
      itemsList.addAll(customItems);
    } else {
      _cart.forEach((productId, qty) {
        itemsList.add({
          'product_id': productId,
          'quantity': qty,
          'notes': _cartNotes[productId],
        });
      });
    }

    final String sharedKey =
        _sharedKey ?? 'order_${DateTime.now().microsecondsSinceEpoch}';
    final int version = _currentVersion;

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
      if (_hasSavedOnce && _serverOrderId != null) {
        final updatedOrder = await ref
            .read(orderActionsProvider)
            .updateOrder(_serverOrderId!, payload);
        _currentVersion = updatedOrder.version;
      } else {
        final createdOrder = await ref
            .read(orderActionsProvider)
            .createOrder(payload);
        _serverOrderId = createdOrder.id;
        _currentVersion = createdOrder.version;
        _hasSavedOnce = true;
        _subscribeToOrderPusher(createdOrder.id);
      }

      if (mounted) {
        setState(() {
          _failureCount = 0;
          _timerPausedForRetry = false;
          _fieldStates.removeWhere(
            (key, value) =>
                key.startsWith('product_qty_') ||
                key.startsWith('product_note_') ||
                key == 'customer' ||
                key == 'warehouse' ||
                key == 'discount' ||
                key == 'order_notes',
          );
          _fieldErrors.removeWhere(
            (key, value) =>
                key.startsWith('product_qty_') ||
                key.startsWith('product_note_') ||
                key == 'customer' ||
                key == 'warehouse' ||
                key == 'discount' ||
                key == 'order_notes',
          );
        });
        if (_lastChangedField != null) {
          _setFieldState(_lastChangedField!, 'success');
          _lastChangedField = null;
        }
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) {
        setState(() {
          _timerPausedForRetry = true;
          _secondsRemaining = 10; // Freeze at 10 for manual retry trigger
          _failureCount++;
        });

        if (_lastChangedField != null) {
          _setFieldState(_lastChangedField!, 'error', error: errorMsg);
        }

        final productsAsync = ref.read(productsListProvider);
        final allProducts = productsAsync.asData?.value ?? <ProductModel>[];

        _showFailedSavePersistentDialog(
          customerName: _selectedCustomer?.name ?? 'کڕیاری نادیار',
          items: itemsList,
          allProducts: allProducts,
          errorMessage: errorMsg,
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

  void _showFailedSavePersistentDialog({
    required String customerName,
    required List<Map<String, dynamic>> items,
    required List<ProductModel> allProducts,
    required String errorMessage,
  }) {
    if (!mounted) return;

    final List<Map<String, dynamic>> localItems = List.from(items);

    showDialog(
      context: context,
      barrierDismissible: false, // User must dismiss manually
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, setDialogState) {
            final theme = Theme.of(context);
            int? retryingProductId;

            Future<void> retrySingleItem(int prodId, int qty) async {
              setDialogState(() {
                retryingProductId = prodId;
              });

              try {
                final List<Map<String, dynamic>> itemsToSave = [];
                _cart.forEach((id, q) {
                  final isFailed = localItems.any(
                    (item) => item['product_id'] == id,
                  );
                  if (!isFailed || id == prodId) {
                    itemsToSave.add({
                      'product_id': id,
                      'quantity': q,
                      'notes': _cartNotes[id],
                    });
                  }
                });

                final warehousesAsync = ref.read(warehouseListProvider);
                final warehouses = warehousesAsync.asData?.value ?? [];
                final warehouseId =
                    _selectedWarehouseId ??
                    (warehouses.any((w) => w.isMain)
                        ? warehouses.firstWhere((w) => w.isMain).id
                        : warehouses.isNotEmpty
                        ? warehouses.first.id
                        : 1);

                final payload = {
                  'customer_id': _selectedCustomer!.id,
                  'warehouse_id': warehouseId,
                  'status': 'PACKING',
                  'discount_type': _discountType,
                  'discount_percent': _discountType == 'PERCENT'
                      ? _discountValue
                      : null,
                  'discount_amount': _discountType == 'FIXED'
                      ? _discountValue
                      : null,
                  'shared_key':
                      _sharedKey ??
                      'order_${DateTime.now().microsecondsSinceEpoch}',
                  'version': _currentVersion,
                  'notes': _notesController.text.trim().isEmpty
                      ? null
                      : _notesController.text.trim(),
                  'items': itemsToSave,
                };

                if (_hasSavedOnce && _serverOrderId != null) {
                  final updatedOrder = await ref
                      .read(orderActionsProvider)
                      .updateOrder(_serverOrderId!, payload);
                  _currentVersion = updatedOrder.version;
                } else {
                  final createdOrder = await ref
                      .read(orderActionsProvider)
                      .createOrder(payload);
                  _serverOrderId = createdOrder.id;
                  _currentVersion = createdOrder.version;
                  _hasSavedOnce = true;
                  _subscribeToOrderPusher(createdOrder.id);
                }

                if (mounted) {
                  setState(() {
                    _fieldStates.remove('product_qty_$prodId');
                    _fieldErrors.remove('product_qty_$prodId');
                  });

                  setDialogState(() {
                    localItems.removeWhere(
                      (item) => item['product_id'] == prodId,
                    );
                    retryingProductId = null;
                  });

                  if (localItems.isEmpty) {
                    setState(() {
                      _failureCount = 0;
                      _timerPausedForRetry = false;
                      _secondsRemaining = 0;
                      _fieldStates.removeWhere(
                        (key, value) =>
                            key.startsWith('product_qty_') ||
                            key.startsWith('product_note_') ||
                            key == 'customer' ||
                            key == 'warehouse' ||
                            key == 'discount' ||
                            key == 'order_notes',
                      );
                      _fieldErrors.removeWhere(
                        (key, value) =>
                            key.startsWith('product_qty_') ||
                            key.startsWith('product_note_') ||
                            key == 'customer' ||
                            key == 'warehouse' ||
                            key == 'discount' ||
                            key == 'order_notes',
                      );
                    });
                    Navigator.pop(context);
                    AppSnackbar.show(
                      context,
                      message: 'هەموو کاڵاکان بە سەرکەوتوویی پاشەکەوتکران',
                      type: SnackbarType.success,
                    );
                  } else {
                    AppSnackbar.show(
                      context,
                      message: 'کاڵاکە بە سەرکەوتوویی پاشەکەوتکرا',
                      type: SnackbarType.success,
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  final errorMsg = e
                      .toString()
                      .replaceAll('Exception:', '')
                      .trim();
                  setDialogState(() {
                    retryingProductId = null;
                  });
                  AppSnackbar.show(
                    context,
                    message: 'پاشەکەوتکردنی کاڵاکە سەرکەوتوو نەبوو: $errorMsg',
                    type: SnackbarType.error,
                  );
                }
              }
            }

            void deleteSingleItem(int prodId) {
              setState(() {
                _cart.remove(prodId);
                _cartNotes.remove(prodId);
              });
              setDialogState(() {
                localItems.removeWhere((item) => item['product_id'] == prodId);
              });

              AppSnackbar.show(
                context,
                message: 'کاڵاکە لە پسوڵە سڕایەوە',
                type: SnackbarType.info,
              );

              if (localItems.isEmpty) {
                setState(() {
                  _failureCount = 0;
                  _timerPausedForRetry = false;
                  _secondsRemaining = 0;
                  _fieldStates.removeWhere(
                    (key, value) =>
                        key.startsWith('product_qty_') ||
                        key.startsWith('product_note_') ||
                        key == 'customer' ||
                        key == 'warehouse' ||
                        key == 'discount' ||
                        key == 'order_notes',
                  );
                  _fieldErrors.removeWhere(
                    (key, value) =>
                        key.startsWith('product_qty_') ||
                        key.startsWith('product_note_') ||
                        key == 'customer' ||
                        key == 'warehouse' ||
                        key == 'discount' ||
                        key == 'order_notes',
                  );
                });
                Navigator.pop(context);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: theme.colorScheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              color: AppColors.danger,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'کێشە لە پاشەکەوتکردنی خۆکار',
                              style: AppTextStyles.h3.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Error details container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'هەڵەی سیستەم: $errorMessage',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Invoice Details Title
                      Text(
                        'زانیارییەکانی پسوڵە:',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Customer row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ناوی کڕیار: $customerName',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Products title
                      Text(
                        _failureCount >= 2
                            ? 'لیستی کاڵاکان (کرداری یەک بە یەک یان سڕینەوە):'
                            : 'لیستی کاڵاکان و بڕی نێردراو:',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Product items list
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: localItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = localItems[index];
                              final prodId = item['product_id'] as int;
                              final qty = item['quantity'] as int;
                              final product = allProducts
                                  .where((p) => p.id == prodId)
                                  .firstOrNull;
                              final prodName =
                                  product?.name ??
                                  'کاڵای نادیار (کۆد: $prodId)';
                              final unit = product?.unit ?? 'دانە';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            prodName,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$qty $unit',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_failureCount >= 2) ...[
                                      if (retryingProductId == prodId)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.primary,
                                                ),
                                          ),
                                        )
                                      else ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cloud_upload_outlined,
                                            color: AppColors.success,
                                            size: 20,
                                          ),
                                          tooltip: 'تەنها ناردنی ئەم کاڵایە',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              retrySingleItem(prodId, qty),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppColors.danger,
                                            size: 20,
                                          ),
                                          tooltip: 'سڕینەوە لە پسوڵە',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              deleteSingleItem(prodId),
                                        ),
                                      ],
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '$qty $unit',
                                          style: AppTextStyles.bodyBold
                                              .copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'تێگەیشتم / داخستن',
                          style: TextStyle(
                            fontFamily: 'Rudaw',
                            fontWeight: FontWeight.bold,
                          ),
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
  }

  void _triggerAutoSave() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _secondsRemaining = 0;
        _timerPausedForRetry = false;
      });
    }
    final productsAsync = ref.read(productsListProvider);
    final warehousesAsync = ref.read(warehouseListProvider);
    if (productsAsync.asData != null && warehousesAsync.asData != null) {
      _autoSaveOrder(warehousesAsync);
    }
  }

  void _triggerDebouncedAutoSave() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _secondsRemaining = 10;
        _timerPausedForRetry = false;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productsAsync = ref.watch(productsListProvider);
    final customersAsync = ref.watch(customerListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    final currentUser = ref.watch(authProvider).user;
    final isSalesman = currentUser?.isSalesman ?? false;
    if (isSalesman &&
        _selectedWarehouseId == null &&
        currentUser?.warehouseId != null) {
      _selectedWarehouseId = currentUser!.warehouseId;
    }

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
                  child: _buildCustomerSelectionDropdown(customersAsync),
                ),
              ),
              const SizedBox(width: 8),
              _buildPriceTypeBadge(),
              if (_secondsRemaining > 0 || _timerPausedForRetry) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _timerPausedForRetry ? _triggerAutoSave : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _timerPausedForRetry
                          ? theme.colorScheme.error.withValues(alpha: 0.15)
                          : (isDark ? AppColors.warningDark : Colors.orange)
                                .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _timerPausedForRetry
                            ? theme.colorScheme.error.withValues(alpha: 0.4)
                            : (isDark ? AppColors.warningDark : Colors.orange)
                                  .withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _timerPausedForRetry
                              ? Icons.refresh
                              : Icons.timer_outlined,
                          size: 16,
                          color: _timerPausedForRetry
                              ? theme.colorScheme.error
                              : (isDark
                                    ? AppColors.warningDark
                                    : Colors.orange),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_secondsRemaining',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _timerPausedForRetry
                                ? theme.colorScheme.error
                                : (isDark
                                      ? AppColors.warningDark
                                      : Colors.orange),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_isSaving) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
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
                            child: _buildProductSelectionSection(productsAsync),
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
                          Expanded(child: _buildCartPanel(allProducts)),
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
    final currentUser = ref.watch(authProvider).user;
    final isSalesman = currentUser?.isSalesman ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
          if (!isSalesman) ...[
            const SizedBox(width: AppSpacing.sm),

            // 2. Warehouse Selection
            Expanded(
              flex: 2,
              child: warehousesAsync.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, _) => const Text('هەڵە لە کۆگا'),
                data: (warehouses) {
                  if (warehouses.isEmpty) {
                    return const Text('کۆگا نییە');
                  }
                  final selectedId =
                      _selectedWarehouseId ??
                      (warehouses.any((w) => w.isMain)
                          ? warehouses.firstWhere((w) => w.isMain).id
                          : warehouses.first.id);

                  return DropdownButtonFormField<int>(
                    key: ValueKey(selectedId),
                    isExpanded: true,
                    initialValue: warehouses.any((w) => w.id == selectedId)
                        ? selectedId
                        : warehouses.first.id,
                    dropdownColor: theme.colorScheme.surface,
                    decoration: InputDecoration(
                      labelText: 'دیاریکردنی کۆگا',
                      prefixIcon: const Icon(
                        Icons.warehouse_outlined,
                        size: 20,
                      ),
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
        if (productsAsync.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.xl * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildProductAutocompleteInput(List<ProductModel> allProducts) {
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
      fieldViewBuilder:
          (
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
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<ProductModel> onSelected,
            Iterable<ProductModel> options,
          ) {
            final screenWidth = MediaQuery.of(context).size.width;

            final RenderBox? renderBox =
                _searchKey.currentContext?.findRenderObject() as RenderBox?;
            final position = renderBox?.localToGlobal(Offset.zero);
            final textFieldX = position?.dx ?? 0.0;

            final isMobile = screenWidth < 600;
            final double dropdownWidth = isMobile
                ? screenWidth
                : (_searchFieldWidth != null
                      ? (_searchFieldWidth! > (screenWidth - 32)
                            ? (screenWidth - 32)
                            : _searchFieldWidth!)
                      : (screenWidth > 450 ? 450.0 : screenWidth - 32));
            final double xOffset = isMobile ? -textFieldX : 0.0;

            return TapRegion(
              groupId: _searchFocusNode,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      borderRadius: isMobile
                          ? BorderRadius.zero
                          : BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      color: theme.colorScheme.surface,
                      child: SizedBox(
                        width: dropdownWidth,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 380),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${options.length} کاڵا دۆزرایەوە',
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        _searchFocusNode.unfocus();
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'داخستن',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.close,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Flexible(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final product = options.elementAt(index);
                                    final unitPrice = _getProductUnitPrice(
                                      product,
                                    );
                                    final qtyInCart = _cart[product.id] ?? 0;

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          _addToCart(product.id);
                                          _searchController.clear();
                                          _searchFocusNode.unfocus();
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted) {
                                                  _searchFocusNode
                                                      .requestFocus();
                                                }
                                              });
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${product.name} زیادکرا بۆ سەبەتە (${qtyInCart + 1})',
                                              ),
                                              backgroundColor:
                                                  AppColors.success,
                                              duration: const Duration(
                                                milliseconds: 900,
                                              ),
                                            ),
                                          );
                                        },
                                        onLongPress: () {
                                          _addToCart(product.id);
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${product.name} زیادکرا (${qtyInCart + 1})',
                                              ),
                                              backgroundColor:
                                                  AppColors.success,
                                              duration: const Duration(
                                                milliseconds: 900,
                                              ),
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
                                                  color: theme
                                                      .colorScheme
                                                      .primaryContainer
                                                      .withValues(alpha: 0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child:
                                                    (product.imagePath !=
                                                            null &&
                                                        product
                                                            .imagePath!
                                                            .isNotEmpty)
                                                    ? GestureDetector(
                                                        onTap: () {
                                                          _showLargeImageDialog(
                                                            context,
                                                            product.imagePath!,
                                                            product.name,
                                                          );
                                                        },
                                                        child: Image.network(
                                                          product.imagePath!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) => Icon(
                                                                Icons
                                                                    .inventory_2_outlined,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                size: 20,
                                                              ),
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        size: 20,
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: AppTextStyles
                                                          .bodyBold,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        if (product
                                                            .barcode
                                                            .isNotEmpty) ...[
                                                          const Icon(
                                                            Icons.qr_code,
                                                            size: 14,
                                                            color: Colors.grey,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            product.barcode,
                                                            style: AppTextStyles
                                                                .caption
                                                                .copyWith(
                                                                  fontFamily: 'monospace',
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                        ],
                                                        Text(
                                                          Formatters.currency(
                                                            unitPrice,
                                                          ),
                                                          style: AppTextStyles
                                                              .caption
                                                              .copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '(${product.unit ?? "دانە"})',
                                                          style: AppTextStyles
                                                              .caption
                                                              .copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (qtyInCart > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primaryContainer
                                                        .withValues(alpha: 0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '$qtyInCart دانە',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
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
      loading: () => SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Text(
        'هەڵە لە بارکردنی کڕیاران',
        style: TextStyle(color: theme.colorScheme.error, fontSize: 11),
      ),
      data: (customers) {
        final dropdownCustomers = List<Customer>.from(customers);
        if (_selectedCustomer != null &&
            !dropdownCustomers.any((c) => c.id == _selectedCustomer!.id)) {
          dropdownCustomers.insert(0, _selectedCustomer!);
        }

        return DropdownButtonFormField<int>(
          key: ValueKey(_selectedCustomer?.id),
          isExpanded: true,
          initialValue:
              dropdownCustomers.any((c) => c.id == _selectedCustomer?.id)
              ? _selectedCustomer?.id
              : null,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'دیاریکردنی کڕیار',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontFamily: 'Rudaw',
            ),
            prefixIcon: Icon(
              Icons.person_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            suffixIcon: _buildFieldStatusIcon('customer', size: 16),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          dropdownColor: theme.colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontFamily: 'Rudaw',
            fontSize: 12,
          ),
          iconEnabledColor: theme.colorScheme.onSurfaceVariant,
          items: dropdownCustomers.map((c) {
            return DropdownMenuItem<int>(
              value: c.id,
              child: Text(
                c.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontFamily: 'Rudaw',
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            final found = dropdownCustomers
                .where((c) => c.id == val)
                .firstOrNull;
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

  Widget _buildPriceTypeBadge() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String priceType = _selectedCustomer != null
        ? (_selectedCustomer!.priceType ?? 'N2')
        : 'N2';

    Color badgeColor;
    if (priceType == 'N1') {
      badgeColor = isDark ? AppColors.successDark : AppColors.n1;
    } else if (priceType == 'N2') {
      badgeColor = isDark ? AppColors.warningDark : AppColors.n2;
    } else {
      badgeColor = isDark ? AppColors.primaryDark : AppColors.n3;
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            priceType,
            style: AppTextStyles.bodyBold.copyWith(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showLargeImageDialog(
    BuildContext context,
    String imageUrl,
    String productName,
  ) {
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
                              const Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'بارکردنی وێنەکە سەرکەوتوو نەبوو',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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

  Widget _buildCartPanel(List<ProductModel> allProducts) {
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildProductAutocompleteInput(allProducts)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _cart.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: const Center(
                            child: Text(
                              'سەبەتە بەتاڵە',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final cartKeys = _cart.keys.toList();
                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                            final isSpecialPrice = _customerSpecialPrices
                                .containsKey(productId);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: null,
                                onLongPress: product != null
                                    ? () => _showSpecialPriceDialog(product)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSpecialPrice
                                          ? theme.colorScheme.primary
                                          : theme.dividerColor.withValues(
                                              alpha: 0.3,
                                            ),
                                      width: isSpecialPrice ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSpecialPrice
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.05,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        product?.name ?? 'کاڵا',
                                                        style: AppTextStyles
                                                            .bodyBold,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (isSpecialPrice)
                                                      const SizedBox(width: 4),
                                                    if (isSpecialPrice)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          'نرخی تایبەت',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            // ignore: deprecated_member_use
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '(${product?.unit ?? "پاکەت"} = ${product?.unitsPerCarton ?? 12} دانە = ${Formatters.currency(unitPrice)})',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color: isSpecialPrice
                                                            ? theme
                                                                  .colorScheme
                                                                  .primary
                                                            : null,
                                                        fontWeight:
                                                            isSpecialPrice
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_buildFieldStatusIcon(
                                                        'product_qty_$productId',
                                                        size: 18,
                                                      ) !=
                                                      null) ...[
                                                    _buildFieldStatusIcon(
                                                      'product_qty_$productId',
                                                      size: 18,
                                                    )!,
                                                    const SizedBox(width: 4),
                                                  ],
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.add_circle_outline,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                    onPressed: () =>
                                                        _addToCart(productId),
                                                  ),
                                                  InkWell(
                                                    onTap: () =>
                                                        _editQuantityDialog(
                                                          productId,
                                                          qty,
                                                          product?.name ??
                                                              'کاڵا',
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 4,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '$qty',
                                                            style: AppTextStyles
                                                                .bodyBold
                                                                .copyWith(
                                                                  decoration:
                                                                      TextDecoration
                                                                          .underline,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            product?.unit ??
                                                                'دانە',
                                                            style: AppTextStyles
                                                                .caption
                                                                .copyWith(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      color: AppColors.danger,
                                                    ),
                                                    onPressed: () {
                                                      if (qty == 1) {
                                                        _confirmDeleteItem(
                                                          productId,
                                                          product?.name ??
                                                              'کاڵا',
                                                        );
                                                      } else {
                                                        _removeFromCart(
                                                          productId,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'کۆ: ${Formatters.currency(unitPrice * qty)}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 8, thickness: 0.5),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.note_alt_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  _cartNotes[productId] ?? '',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'تێبینی بۆ ئەم کاڵایە...',
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 8,
                                                    ),
                                                border: InputBorder.none,
                                                suffixIcon:
                                                    _buildFieldStatusIcon(
                                                      'product_note_$productId',
                                                      size: 16,
                                                    ),
                                                suffixIconConstraints:
                                                    const BoxConstraints(
                                                      minWidth: 16,
                                                      minHeight: 16,
                                                    ),
                                              ),
                                              onChanged: (val) {
                                                _cartNotes[productId] = val;
                                                _lastChangedField =
                                                    'product_note_$productId';
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
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.danger,
                        ),
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
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              width: 1,
                            ),
                            right: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
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
                            Text(
                              'داشکان: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _discountType,
                                dropdownColor: theme.colorScheme.surface,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'FIXED',
                                    child: Text(
                                      'بڕ (پارە)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PERCENT',
                                    child: Text(
                                      '% (ڕێژە)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _lastChangedField = 'discount';
                                    setState(() {
                                      _discountType = val;
                                      if (_discountType == 'PERCENT' &&
                                          _discountValue > 100) {
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
                              child: AppTextField(
                                key: ValueKey(
                                  'discount_field_${_discountValue}_$_discountType',
                                ),
                                controller:
                                    TextEditingController(
                                        text: _discountValue == 0
                                            ? ''
                                            : (_discountValue ==
                                                      _discountValue
                                                          .roundToDouble()
                                                  ? _discountValue
                                                        .toInt()
                                                        .toString()
                                                  : _discountValue.toString()),
                                      )
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                          offset:
                                              (_discountValue == 0
                                                      ? ''
                                                      : (_discountValue ==
                                                                _discountValue
                                                                    .roundToDouble()
                                                            ? _discountValue
                                                                  .toInt()
                                                                  .toString()
                                                            : _discountValue
                                                                  .toString()))
                                                  .length,
                                        ),
                                      ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                borderRadius: BorderRadius.zero,
                                customDecoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  border: InputBorder.none,
                                  hintText: '0',
                                  suffixIcon: _buildFieldStatusIcon('discount'),
                                ),
                                onChanged: (val) {
                                  final parsed = double.tryParse(val) ?? 0.0;
                                  _lastChangedField = 'discount';
                                  setState(() {
                                    _discountValue = parsed;
                                    if (_discountType == 'PERCENT' &&
                                        _discountValue > 100) {
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
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              width: 1,
                            ),
                            left: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
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
                            Text(
                              'کۆ:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
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
