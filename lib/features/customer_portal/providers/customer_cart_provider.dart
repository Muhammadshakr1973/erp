import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/warehouse_provider.dart';

class CustomerCartState {
  final Map<int, double> items;
  final OrderModel? activeDraftOrder;
  final bool isSyncing;
  final bool isCompleting;
  final bool hasPendingChanges;
  final String? error;
  final String? lastCompletedOrderNumber;

  const CustomerCartState({
    this.items = const {},
    this.activeDraftOrder,
    this.isSyncing = false,
    this.isCompleting = false,
    this.hasPendingChanges = false,
    this.error,
    this.lastCompletedOrderNumber,
  });

  double get totalQuantity =>
      items.values.fold<double>(0.0, (sum, qty) => sum + qty);

  int get distinctItemCount => items.values.where((qty) => qty > 0).length;

  CustomerCartState copyWith({
    Map<int, double>? items,
    OrderModel? activeDraftOrder,
    bool clearActiveDraft = false,
    bool? isSyncing,
    bool? isCompleting,
    bool? hasPendingChanges,
    String? error,
    bool clearError = false,
    String? lastCompletedOrderNumber,
    bool clearLastCompletedOrder = false,
  }) {
    return CustomerCartState(
      items: items ?? this.items,
      activeDraftOrder: clearActiveDraft
          ? null
          : (activeDraftOrder ?? this.activeDraftOrder),
      isSyncing: isSyncing ?? this.isSyncing,
      isCompleting: isCompleting ?? this.isCompleting,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
      error: clearError ? null : (error ?? this.error),
      lastCompletedOrderNumber: clearLastCompletedOrder
          ? null
          : (lastCompletedOrderNumber ?? this.lastCompletedOrderNumber),
    );
  }
}

class CustomerCartNotifier extends StateNotifier<CustomerCartState> {
  final Ref _ref;
  Timer? _debounceTimer;
  bool _dirty = false;
  bool _isSyncLoopRunning = false;
  Completer<void>? _syncIdleCompleter;
  ProviderSubscription<AsyncValue<List<OrderModel>>>? _ordersSubscription;

  CustomerCartNotifier(this._ref) : super(const CustomerCartState()) {
    final initialOrders = _ref.read(ordersListProvider).valueOrNull;
    if (initialOrders != null) {
      _hydrateFromOrders(initialOrders);
    }

    _ordersSubscription = _ref.listen<AsyncValue<List<OrderModel>>>(
      ordersListProvider,
      (_, next) {
        final orders = next.valueOrNull;
        if (orders != null) {
          _hydrateFromOrders(orders);
        }
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _ordersSubscription?.close();
    super.dispose();
  }

  void _hydrateFromOrders(List<OrderModel> orders) {
    if (!mounted) return;
    if (_isSyncLoopRunning ||
        _debounceTimer != null ||
        _dirty ||
        state.isCompleting) {
      return;
    }

    final draft = orders
        .where((o) => o.status.toUpperCase() == OrderModel.statusDraft)
        .firstOrNull;

    if (draft != null) {
      final hydratedItems = <int, double>{};
      for (final item in draft.items) {
        if (item.quantity > 0) {
          hydratedItems[item.productId] = item.quantity;
        }
      }
      state = state.copyWith(
        items: hydratedItems,
        activeDraftOrder: draft,
        clearLastCompletedOrder: hydratedItems.isNotEmpty,
      );
    } else if (state.activeDraftOrder != null) {
      state = state.copyWith(
        items: const {},
        clearActiveDraft: true,
      );
    }
  }

  Customer? get currentCustomer => _ref.read(authProvider).user?.customer;

  int resolveTargetWarehouseId() {
    final draftWarehouseId = state.activeDraftOrder?.warehouseId;
    if (draftWarehouseId != null && draftWarehouseId > 0) {
      return draftWarehouseId;
    }

    final warehouses =
        _ref.read(warehouseListProvider).asData?.value ?? const [];
    final sellableWarehouses = warehouses
        .where((w) => w.isActive && w.canSell && !w.isVan && !w.isReserve)
        .toList();

    return sellableWarehouses.where((w) => w.isMain).firstOrNull?.id ??
        sellableWarehouses.firstOrNull?.id ??
        1;
  }

  double getProductPrice(ProductModel product) {
    final customer = currentCustomer;
    final specialPrice = customer?.specialPrices[product.id];
    if (specialPrice != null && specialPrice > 0) {
      return specialPrice;
    }

    switch ((customer?.priceType ?? 'N2').toUpperCase()) {
      case 'N1':
        return product.priceN1;
      case 'N3':
        return product.priceN3;
      case 'N2':
      default:
        return product.priceN2;
    }
  }

  bool hasSpecialPrice(ProductModel product) {
    final sp = currentCustomer?.specialPrices[product.id];
    return sp != null && sp > 0;
  }

  double getSavedQuantityInDraft(int productId) {
    final draft = state.activeDraftOrder;
    if (draft == null) return 0.0;
    return draft.items
            .where((item) => item.productId == productId)
            .firstOrNull
            ?.quantity ??
        0.0;
  }

  double getAvailableStock(ProductModel product) {
    final warehouseId = resolveTargetWarehouseId();
    final warehouseStock = product.getStockForWarehouse(warehouseId);
    final savedInDraft = getSavedQuantityInDraft(product.id);
    return warehouseStock + savedInDraft;
  }

  double _roundQty(double value) => (value * 1000).round() / 1000.0;

  double getRemainingStock(ProductModel product) {
    final totalAvailable = getAvailableStock(product);
    final currentQty = state.items[product.id] ?? 0.0;
    final remaining = totalAvailable - currentQty;
    return remaining <= 1e-6 ? 0.0 : _roundQty(remaining);
  }

  String? incrementProduct(ProductModel product) {
    final totalAvailable = getAvailableStock(product);
    final currentQty = state.items[product.id] ?? 0.0;

    if (totalAvailable <= 1e-6) {
      return 'ئەم کاڵایە لە ستۆک بەردەست نییە';
    }
    final remaining = _roundQty(totalAvailable - currentQty);
    if (remaining <= 1e-6) {
      return 'تەنها ${Formatters.cleanNumberString(totalAvailable)} دانە لە ستۆک بەردەستە';
    }

    final nextQty = remaining < 1.0
        ? _roundQty(totalAvailable)
        : _roundQty(currentQty + 1.0);

    setQuantity(product.id, nextQty);
    return null;
  }

  void decrementProduct(int productId) {
    final currentQty = state.items[productId] ?? 0.0;
    if (currentQty <= 0) return;

    if (currentQty > 1.0 + 1e-6) {
      setQuantity(productId, _roundQty(currentQty - 1.0));
    } else if (currentQty > 0.5 + 1e-6) {
      setQuantity(productId, 0.5);
    } else {
      removeProduct(productId);
    }
  }

  void setQuantity(int productId, double quantity) {
    final nextItems = Map<int, double>.from(state.items);
    if (quantity > 0) {
      nextItems[productId] = quantity;
    } else {
      nextItems.remove(productId);
    }

    state = state.copyWith(
      items: nextItems,
      hasPendingChanges: true,
      clearError: true,
      clearLastCompletedOrder: quantity > 0,
    );

    _scheduleSync();
  }

  void applyVariantQuantities(
    List<ProductModel> variants,
    Map<int, double> updatedQuantities,
  ) {
    final nextItems = Map<int, double>.from(state.items);
    bool anyPositive = false;

    for (final v in variants) {
      final qty = updatedQuantities[v.id] ?? 0.0;
      if (qty > 0) {
        nextItems[v.id] = qty;
        anyPositive = true;
      } else {
        nextItems.remove(v.id);
      }
    }

    state = state.copyWith(
      items: nextItems,
      hasPendingChanges: true,
      clearError: true,
      clearLastCompletedOrder: anyPositive,
    );

    _scheduleSync();
  }

  void removeProduct(int productId) {
    final nextItems = Map<int, double>.from(state.items)..remove(productId);
    state = state.copyWith(
      items: nextItems,
      hasPendingChanges: true,
      clearError: true,
    );
    _scheduleSync();
  }

  void _scheduleSync() {
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      _debounceTimer = null;
      _startSyncLoopIfNeeded();
    });
  }

  Future<void> flushSync() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_dirty) {
      _startSyncLoopIfNeeded();
    }

    if (_syncIdleCompleter != null) {
      await _syncIdleCompleter!.future;
    }
  }

  void _startSyncLoopIfNeeded() {
    if (_isSyncLoopRunning) return;
    unawaited(_runSyncLoop());
  }

  bool _isConcurrencyConflictError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('409') ||
        msg.contains('conflict_version') ||
        msg.contains('هاوکاتی') ||
        msg.contains('نوێ بکەرەوە') ||
        msg.contains('نوێکراوەتەوە') ||
        msg.contains('version');
  }

  Future<void> _runSyncLoop() async {
    if (_isSyncLoopRunning) return;
    _isSyncLoopRunning = true;
    _syncIdleCompleter = Completer<void>();
    bool conflictRetried = false;

    if (mounted) {
      state = state.copyWith(isSyncing: true, clearError: true);
    }

    try {
      while (_dirty && mounted) {
        _dirty = false;
        final targetItems = Map<int, double>.from(state.items);
        final currentDraft = state.activeDraftOrder;
        final customer = currentCustomer;

        if (targetItems.isEmpty) {
          if (currentDraft != null) {
            await _ref
                .read(orderActionsProvider)
                .deleteOrder(currentDraft.id.toString());
            if (mounted) {
              state = state.copyWith(clearActiveDraft: true);
            }
            unawaited(
              _ref.read(productsListProvider.notifier).refreshProductsSilently(),
            );
          }
          continue;
        }

        if (customer == null || customer.id <= 0) {
          throw Exception('زانیاری هەژماری کڕیار نەدۆزرایەوە');
        }

        final itemsList = targetItems.entries
            .map((e) => {'product_id': e.key, 'quantity': e.value})
            .toList();

        final warehouseId = resolveTargetWarehouseId();

        if (currentDraft == null) {
          final payload = {
            'customer_id': customer.id,
            'warehouse_id': warehouseId,
            'status': OrderModel.statusDraft,
            'price_type': (customer.priceType ?? 'N2').toUpperCase(),
            'is_manual_price_type': false,
            'version': 1,
            'items': itemsList,
          };

          final created = await _ref
              .read(orderActionsProvider)
              .createOrder(payload);
          if (mounted) {
            state = state.copyWith(activeDraftOrder: created);
          }
          unawaited(
            _ref.read(productsListProvider.notifier).refreshProductsSilently(),
          );
        } else {
          final payload = {
            'customer_id': customer.id,
            'warehouse_id': warehouseId,
            'status': OrderModel.statusDraft,
            'price_type': (customer.priceType ?? 'N2').toUpperCase(),
            'is_manual_price_type': false,
            'version': currentDraft.version,
            'notes': currentDraft.notes,
            'items': itemsList,
          };

          try {
            final updated = await _ref
                .read(orderActionsProvider)
                .updateOrder(currentDraft.id, payload);
            if (mounted) {
              state = state.copyWith(activeDraftOrder: updated);
            }
          } catch (e) {
            if (!conflictRetried && _isConcurrencyConflictError(e)) {
              conflictRetried = true;
              await _ref
                  .read(ordersListProvider.notifier)
                  .refreshSingleOrder(currentDraft.id);
              final refreshedDraft = _ref
                  .read(ordersListProvider)
                  .valueOrNull
                  ?.where(
                    (o) =>
                        o.id == currentDraft.id &&
                        o.status.toUpperCase() == OrderModel.statusDraft,
                  )
                  .firstOrNull;
              if (refreshedDraft != null && mounted) {
                state = state.copyWith(activeDraftOrder: refreshedDraft);
                _dirty = true;
                continue;
              }
            }
            rethrow;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: Formatters.cleanError(e));
      }
      unawaited(_ref.read(ordersListProvider.notifier).refreshSilently());
      unawaited(
        _ref.read(productsListProvider.notifier).refreshProductsSilently(),
      );
    } finally {
      _isSyncLoopRunning = false;
      final completer = _syncIdleCompleter;
      _syncIdleCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          hasPendingChanges: _dirty || _debounceTimer != null,
        );
      }
    }
  }

  Future<String> completeOrder() async {
    if (state.items.isEmpty) {
      throw Exception('تکایە سەرەتا کاڵایەک بۆ پسوڵەکە زیاد بکە');
    }

    state = state.copyWith(isCompleting: true, clearError: true);

    try {
      await flushSync();

      if (state.error != null) {
        throw Exception(state.error!);
      }

      final draft = state.activeDraftOrder;
      if (draft == null) {
        throw Exception('پسوڵەکە ئامادە نەبووە، تکایە دووبارە هەوڵبدەرەوە');
      }

      await _ref
          .read(orderActionsProvider)
          .updateOrderStatus(draft.id.toString(), OrderModel.statusPacking);

      final completedNumber = draft.orderNumber;
      if (mounted) {
        state = CustomerCartState(
          items: const {},
          activeDraftOrder: null,
          isSyncing: false,
          isCompleting: false,
          hasPendingChanges: false,
          lastCompletedOrderNumber: completedNumber,
        );
      }

      return completedNumber;
    } catch (e) {
      final cleanMsg = Formatters.cleanError(e);
      if (mounted) {
        state = state.copyWith(isCompleting: false, error: cleanMsg);
      }
      throw Exception(cleanMsg);
    }
  }

  double computeSubtotal(Map<int, ProductModel> productMap) {
    double sum = 0.0;
    for (final entry in state.items.entries) {
      if (entry.value <= 0) continue;
      final prod = productMap[entry.key];
      final draftItem = state.activeDraftOrder?.items
          .where((i) => i.productId == entry.key)
          .firstOrNull;
      final unitPrice = prod != null
          ? getProductPrice(prod)
          : (draftItem?.unitPrice ?? 0.0);
      sum += unitPrice * entry.value;
    }
    return sum;
  }

  double computePermanentDiscountAmount(double subtotal) {
    final percent = (currentCustomer?.permanentDiscount ?? 0.0).clamp(0.0, 100.0);
    if (percent <= 0) return 0.0;
    return ((subtotal * percent) / 100.0).roundToDouble();
  }
}

final customerCartProvider =
    StateNotifierProvider<CustomerCartNotifier, CustomerCartState>((ref) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return CustomerCartNotifier(ref);
    });
