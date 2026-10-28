import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/app_dialog.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/suppliers_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/models/receipt_data.dart';
import '../../shared/services/receipt_print_service.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_requirement_model.dart';
import '../providers/purchase_provider.dart';
import '../../products/views/supplier_reconciliation_dialog.dart';
import 'supplier_form_dialog.dart';
import 'purchase_order_builder_dialog.dart';

enum PurchaseUnitType { baseUnit, carton }
enum CartonContentMode { byUnit, byPieces }

class PurchaseCartItem {
  final ProductModel product;
  PurchaseUnitType unitType;
  int quantity; // Base unit count OR carton count
  CartonContentMode cartonContentMode;
  int cartonContentValue; // If byUnit: units per carton. If byPieces: pieces per carton.
  double unitCost;
  double? cartonCost;
  String? notes;

  PurchaseCartItem({
    required this.product,
    this.unitType = PurchaseUnitType.baseUnit,
    this.quantity = 1,
    this.cartonContentMode = CartonContentMode.byUnit,
    int? cartonContentValue,
    double? unitCost,
    this.cartonCost,
    this.notes,
  })  : cartonContentValue = cartonContentValue ?? (product.unitsPerCarton > 0 ? 10 : 1),
        unitCost = unitCost ?? product.costPrice;

  String get baseUnitName {
    final u = product.unit?.trim();
    return (u != null && u.isNotEmpty) ? u : 'دانە';
  }

  int get piecesPerUnit {
    return product.unitsPerCarton > 0 ? product.unitsPerCarton : 1;
  }

  int get unitsPerOneCarton {
    if (cartonContentMode == CartonContentMode.byUnit) {
      return cartonContentValue > 0 ? cartonContentValue : 1;
    } else {
      final p = piecesPerUnit;
      final val = (cartonContentValue / p).round();
      return val > 0 ? val : 1;
    }
  }

  int get totalStockUnits {
    if (unitType == PurchaseUnitType.baseUnit) {
      return quantity > 0 ? quantity : 1;
    } else {
      return (quantity > 0 ? quantity : 1) * unitsPerOneCarton;
    }
  }

  double get totalLineCost {
    if (unitType == PurchaseUnitType.carton && cartonCost != null && cartonCost! > 0) {
      return (quantity > 0 ? quantity : 1) * cartonCost!;
    }
    return totalStockUnits * unitCost;
  }

  int get effectiveUnitCostForServer {
    if (totalStockUnits <= 0) return unitCost.round();
    return (totalLineCost / totalStockUnits).round();
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'product_barcode': product.barcode,
      'product_unit': product.unit,
      'product_cost_price': product.costPrice,
      'product_price_n1': product.priceN1,
      'product_price_n2': product.priceN2,
      'product_price_n3': product.priceN3,
      'product_units_per_carton': product.unitsPerCarton,
      'product_sku': product.sku,
      'unit_type': unitType == PurchaseUnitType.carton ? 'carton' : 'baseUnit',
      'quantity': quantity,
      'carton_content_mode':
          cartonContentMode == CartonContentMode.byPieces ? 'byPieces' : 'byUnit',
      'carton_content_value': cartonContentValue,
      'unit_cost': unitCost,
      'carton_cost': cartonCost,
      'notes': notes,
    };
  }

  factory PurchaseCartItem.fromJson(Map<String, dynamic> json,
      {ProductModel? matchedProduct}) {
    final prod = matchedProduct ??
        ProductModel(
          id: json['product_id'] ?? 0,
          name: json['product_name'] ?? '',
          barcode: json['product_barcode'] ?? '',
          sku: json['product_sku'],
          unit: json['product_unit'],
          costPrice: (json['product_cost_price'] as num?)?.toDouble() ?? 0.0,
          priceN1: (json['product_price_n1'] as num?)?.toDouble() ?? 0.0,
          priceN2: (json['product_price_n2'] as num?)?.toDouble() ?? 0.0,
          priceN3: (json['product_price_n3'] as num?)?.toDouble() ?? 0.0,
          unitsPerCarton:
              (json['product_units_per_carton'] as num?)?.toInt() ?? 1,
        );

    final uType = (json['unit_type'] == 'carton')
        ? PurchaseUnitType.carton
        : PurchaseUnitType.baseUnit;
    final cMode = (json['carton_content_mode'] == 'byPieces')
        ? CartonContentMode.byPieces
        : CartonContentMode.byUnit;

    return PurchaseCartItem(
      product: prod,
      unitType: uType,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      cartonContentMode: cMode,
      cartonContentValue: (json['carton_content_value'] as num?)?.toInt(),
      unitCost: (json['unit_cost'] as num?)?.toDouble(),
      cartonCost: (json['carton_cost'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

class AdminPurchasesScreen extends ConsumerStatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  ConsumerState<AdminPurchasesScreen> createState() =>
      _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends ConsumerState<AdminPurchasesScreen>
    with SingleTickerProviderStateMixin {
  static const String _kPurchaseCartDraftKey = 'admin_purchase_cart_draft';

  late TabController _tabController;
  final Set<int> _selectedRequirementIds = {};
  bool _isConverting = false;

  final List<PurchaseCartItem> _purchaseCart = [];
  int? _activeDraftOrderId;
  int? _lastLoadedDraftOrderId;
  int? _selectedSupplierId; // null = دابینکەری نوێ (بێناو)
  int? _selectedWarehouseId;
  final TextEditingController _poNotesController = TextEditingController();
  final TextEditingController _poPaidAmountController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  final FocusNode _productSearchFocusNode = FocusNode();

  final Set<int> _checkedProductIds = {};
  String _lowStockFilter = 'all'; // 'all', 'checked', 'unchecked'
  bool _isLowStockExpanded = true;
  bool _isSubmittingPO = false;
  bool _userModifiedPaidAmount = false;

  bool _hasRestoredDraft = false;
  Timer? _draftDebounceTimer;

  @override
  void initState() {
    super.initState();
    _poPaidAmountController.text = '0';
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _poNotesController.addListener(_onCartDataChanged);
    _poPaidAmountController.addListener(_onCartDataChanged);
  }

  void _onCartDataChanged() {
    _draftDebounceTimer?.cancel();
    _draftDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _saveCartDraft();
    });
  }

  void _loadDraftOrderData(PurchaseOrderModel draft, List<ProductModel> allProducts) {
    _selectedSupplierId = draft.supplierId > 0 ? draft.supplierId : null;
    _selectedWarehouseId = draft.warehouseId;
    _poNotesController.text = draft.notes ?? '';
    _poPaidAmountController.text = draft.paidAmount > 0
        ? draft.paidAmount.toInt().toString()
        : draft.totalAmount.toInt().toString();
    _userModifiedPaidAmount = draft.paidAmount > 0;

    _purchaseCart.clear();
    for (final it in draft.items) {
      final matched = allProducts.where((p) => p.id == it.productId).firstOrNull;
      final prod = matched ??
          ProductModel(
            id: it.productId,
            name: it.productName,
            barcode: '',
            costPrice: it.unitCost.toDouble(),
            priceN1: 0,
            priceN2: 0,
            priceN3: 0,
            unitsPerCarton: it.unitsPerCarton,
          );

      _purchaseCart.add(PurchaseCartItem(
        product: prod,
        quantity: it.quantity,
        unitCost: it.unitCost.toDouble(),
      ));
    }
  }

  Future<void> _createNewDraftInvoice(List<dynamic> warehouses) async {
    try {
      final defaultWhId = _selectedWarehouseId ??
          (warehouses.any((w) => (w as dynamic).isMain == true)
              ? (warehouses.firstWhere((w) => (w as dynamic).isMain == true) as dynamic).id
              : (warehouses.isNotEmpty ? (warehouses.first as dynamic).id : 1));

      final newOrder = await ref.read(purchaseActionsProvider).createPurchaseOrder(
        supplierId: _selectedSupplierId,
        warehouseId: defaultWhId,
        items: [],
        autoReceive: false,
        notes: null,
      );

      setState(() {
        _activeDraftOrderId = newOrder.id;
        _lastLoadedDraftOrderId = newOrder.id;
        _purchaseCart.clear();
        _poNotesController.clear();
        _poPaidAmountController.text = '0';
        _userModifiedPaidAmount = false;
      });

      ref.invalidate(purchaseOrdersProvider);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'پسوڵەی نوێ #${newOrder.orderNumber} دروستکرا و تۆمارکرا',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'کێشە لە دروستکردنی پسوڵەی نوێ: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteCurrentDraftOrder() async {
    if (_activeDraftOrderId == null) return;

    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی پسوڵەی کڕین',
      message: 'ئایا دڵنیایت لە سڕینەوەی ئەم پسوڵەیە لە داتابەیس؟',
      confirmText: 'بەڵێ، بسڕەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      try {
        final idToDelete = _activeDraftOrderId!;
        await ref.read(purchaseActionsProvider).deletePurchaseOrder(idToDelete);
        setState(() {
          _activeDraftOrderId = null;
          _lastLoadedDraftOrderId = null;
          _purchaseCart.clear();
          _poNotesController.clear();
          _poPaidAmountController.text = '0';
        });
        await _clearCartDraft();
        ref.invalidate(purchaseOrdersProvider);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'پسوڵەی کڕین بەسەرکەوتوویی سڕایەوە',
            type: SnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کێشە لە سڕینەوە: $e',
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  void _switchDraftOrder(
    int draftId,
    List<PurchaseOrderModel> draftOrders,
    List<ProductModel> allProducts,
  ) async {
    if (_activeDraftOrderId == draftId) return;

    if (_activeDraftOrderId != null && _purchaseCart.isNotEmpty) {
      await _saveCartDraft(forceSaveToBackend: true);
    }

    final draft = draftOrders.firstWhere((d) => d.id == draftId);
    setState(() {
      _activeDraftOrderId = draftId;
      _lastLoadedDraftOrderId = draftId;
      _loadDraftOrderData(draft, allProducts);
    });
  }

  Future<void> _saveCartDraft({bool forceSaveToBackend = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_purchaseCart.isEmpty && _activeDraftOrderId == null) {
        await prefs.remove(_kPurchaseCartDraftKey);
        return;
      }
      final draftData = {
        'active_draft_order_id': _activeDraftOrderId,
        'items': _purchaseCart.map((item) => item.toJson()).toList(),
        'supplier_id': _selectedSupplierId,
        'warehouse_id': _selectedWarehouseId,
        'notes': _poNotesController.text,
        'paid_amount': _poPaidAmountController.text,
      };
      await prefs.setString(_kPurchaseCartDraftKey, jsonEncode(draftData));

      final warehousesAsync = ref.read(warehouseListProvider);
      final warehouses = warehousesAsync.asData?.value ?? [];
      final warehouseId = _selectedWarehouseId ??
          (warehouses.any((w) => w.isMain)
              ? warehouses.firstWhere((w) => w.isMain).id
              : (warehouses.isNotEmpty ? warehouses.first.id : 1));

      final itemsPayload = _purchaseCart.map((item) {
        return {
          'product_id': item.product.id,
          'quantity': item.totalStockUnits,
          'unit_cost': item.effectiveUnitCostForServer,
        };
      }).toList();

      final textVal = _poPaidAmountController.text.trim();
      final parsedPaid = double.tryParse(textVal);
      final totalAmount = _calculateCartTotal();
      final paidAmount = parsedPaid ?? (_userModifiedPaidAmount ? 0.0 : totalAmount);

      if (_activeDraftOrderId != null) {
        await ref.read(purchaseActionsProvider).updatePurchaseOrder(
          orderId: _activeDraftOrderId!,
          supplierId: _selectedSupplierId,
          warehouseId: warehouseId,
          items: itemsPayload,
          paidAmount: paidAmount,
          autoReceive: false,
          notes: _poNotesController.text.trim().isEmpty ? null : _poNotesController.text.trim(),
        );
      } else if (_purchaseCart.isNotEmpty && forceSaveToBackend) {
        final newOrder = await ref.read(purchaseActionsProvider).createPurchaseOrder(
          supplierId: _selectedSupplierId,
          warehouseId: warehouseId,
          items: itemsPayload,
          paidAmount: paidAmount,
          autoReceive: false,
          notes: _poNotesController.text.trim().isEmpty ? null : _poNotesController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _activeDraftOrderId = newOrder.id;
            _lastLoadedDraftOrderId = newOrder.id;
          });
        }
      }
    } catch (e) {
      debugPrint('Error saving purchase cart draft: $e');
    }
  }

  Future<void> _clearCartDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPurchaseCartDraftKey);
    } catch (e) {
      debugPrint('Error clearing purchase cart draft: $e');
    }
  }

  Future<void> _restoreCartDraft(List<ProductModel> allProducts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString(_kPurchaseCartDraftKey);
      if (draftStr == null || draftStr.isEmpty) return;

      final dynamic decoded = jsonDecode(draftStr);
      if (decoded is! Map<String, dynamic>) return;

      final List<dynamic>? rawItems = decoded['items'];
      if (rawItems == null || rawItems.isEmpty) return;

      final List<PurchaseCartItem> restoredItems = [];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final prodId = raw['product_id'];
          ProductModel? matched;
          if (prodId != null) {
            matched = allProducts.where((p) => p.id == prodId).firstOrNull;
          }
          restoredItems.add(
              PurchaseCartItem.fromJson(raw, matchedProduct: matched));
        }
      }

      if (restoredItems.isNotEmpty && mounted) {
        setState(() {
          _purchaseCart.clear();
          _purchaseCart.addAll(restoredItems);
          if (decoded['supplier_id'] != null) {
            _selectedSupplierId = decoded['supplier_id'] as int?;
          }
          if (decoded['warehouse_id'] != null) {
            _selectedWarehouseId = decoded['warehouse_id'] as int?;
          }
          final savedNotes = decoded['notes'] as String?;
          if (savedNotes != null && savedNotes.isNotEmpty) {
            _poNotesController.text = savedNotes;
          }
          final savedPaid = decoded['paid_amount'] as String?;
          if (savedPaid != null && savedPaid.isNotEmpty) {
            _poPaidAmountController.text = savedPaid;
            _userModifiedPaidAmount = true;
          } else {
            _updatePaidAmountToTotal(force: true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error restoring purchase cart draft: $e');
    }
  }

  void _clearEntireCart() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی سەبەتەی کڕین',
      message: 'ئایا دڵنیایت لە سڕینەوەی تەواوی کاڵاکانی ئەم پسوڵەیە؟',
      confirmText: 'بەڵێ، بسڕەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      setState(() {
        _purchaseCart.clear();
        _poNotesController.clear();
        _poPaidAmountController.text = '0';
        _userModifiedPaidAmount = false;
      });
      _clearCartDraft();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'کاڵاکانی پسوڵە بەسەرکەوتوویی سڕانەوە',
          type: SnackbarType.info,
        );
      }
    }
  }

  @override
  void dispose() {
    _draftDebounceTimer?.cancel();
    _poNotesController.removeListener(_onCartDataChanged);
    _poPaidAmountController.removeListener(_onCartDataChanged);
    _tabController.dispose();
    _poNotesController.dispose();
    _poPaidAmountController.dispose();
    _productSearchController.dispose();
    _productSearchFocusNode.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SupplierFormDialog(),
    ).then((success) {
      if (success == true) {
        ref.invalidate(suppliersListProvider);
      }
    });
  }

  void _showEditSupplierDialog(BuildContext context, SupplierModel supplier) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    ).then((success) {
      if (success == true) {
        ref.invalidate(suppliersListProvider);
      }
    });
  }

  void _deleteSupplier(SupplierModel supplier) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی کۆمپانیا',
      message: 'دڵنیایت لە سڕینەوەی کۆمپانیای "${supplier.name}"؟',
      confirmText: 'سڕینەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(supplierActionsProvider).deleteSupplier(supplier.id);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کۆمپانیا بە سەرکەوتوویی سڕایەوە',
            type: SnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کێشە لە سڕینەوە: $e',
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  void _convertSelectedToPO() async {
    if (_isConverting) return;
    final requirements =
        ref.read(purchaseRequirementsProvider).valueOrNull ??
        <PurchaseRequirementModel>[];
    final selectedRequirements = requirements
        .where((requirement) => _selectedRequirementIds.contains(requirement.id))
        .toList();

    setState(() => _isConverting = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PurchaseOrderBuilderDialog(
          requirements: selectedRequirements,
        ),
      );
      if (created == true && mounted) {
        setState(() => _selectedRequirementIds.clear());
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _confirmPO(PurchaseOrderModel order) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'پەسەندکردنی پسوڵەی کڕین',
      message:
          'ئایا دڵنیایت لە پەسەندکردنی پسوڵەی کڕینی #${order.orderNumber}؟',
      confirmText: 'پەسەندکردن',
      cancelText: 'پەشیمانبوونەوە',
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(purchaseActionsProvider).confirmPurchaseOrder(order.id);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'پسوڵەی کڕین بەسەرکەوتوویی پەسەندکرا',
            type: SnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: e.toString().replaceAll('Exception: ', ''),
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  void _receivePO(PurchaseOrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceivePODialog(
        order: order,
        actions: ref.read(purchaseActionsProvider),
      ),
    );

    if (confirmed == true && mounted) {
      AppSnackbar.show(
        context,
        message: 'کرداری وەرگرتنی پسوڵەی کڕین جێبەجێکرا',
        type: SnackbarType.success,
      );
    }
  }

  void _cancelPO(PurchaseOrderModel order) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'هەڵوەشاندنەوەی پسوڵەی کڕین',
      message:
          'ئایا دڵنیایت لە هەڵوەشاندنەوەی پسوڵەی کڕینی #${order.orderNumber}؟ بەم کارە داواکارییەکان دەگەڕێنەوە لیستی داواکاری کراوە.',
      confirmText: 'هەڵوەشاندنەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(purchaseActionsProvider).cancelPurchaseOrder(order.id);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'پسوڵەی کڕین بەسەرکەوتوویی هەڵوەشێنرایەوە',
            type: SnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: e.toString().replaceAll('Exception: ', ''),
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'suppliers.manage',
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازاڕ و کۆمپانیا', style: AppTextStyles.h2),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              tooltip: 'دروستکردنی پسوڵەی کڕین',
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: _isConverting ? null : _convertSelectedToPO,
            ),
          if (_tabController.index == 2)
            IconButton(
              icon: const Icon(AppIcons.add),
              onPressed: () => _showAddSupplierDialog(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'کڕین'),
            Tab(text: 'پسوڵەکانی کڕین'),
            Tab(text: 'کۆمپانیاکان'),
          ],
          labelStyle: AppTextStyles.bodyBold,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(context),
          _buildPurchaseOrdersTab(context),
          _buildSuppliersTab(context),
        ],
      ),
    );
  }

  double _calculateCartTotal() {
    return _purchaseCart.fold(0.0, (sum, item) => sum + item.totalLineCost);
  }

  void _updatePaidAmountToTotal({bool force = false}) {
    final total = _calculateCartTotal();
    if (force || !_userModifiedPaidAmount) {
      _poPaidAmountController.text = total > 0 ? total.toInt().toString() : '0';
    }
    if (mounted) setState(() {});
    _saveCartDraft();
  }

  void _addProductToCart(ProductModel product, {bool clearSearch = true}) {
    int currentQty = 1;
    setState(() {
      final existingIndex = _purchaseCart.indexWhere((item) => item.product.id == product.id);
      if (existingIndex >= 0) {
        _purchaseCart[existingIndex].quantity += 1;
        currentQty = _purchaseCart[existingIndex].quantity;
      } else {
        _purchaseCart.add(PurchaseCartItem(
          product: product,
          quantity: 1,
        ));
        currentQty = 1;
      }
      if (clearSearch) {
        _productSearchController.clear();
      }
      _updatePaidAmountToTotal();
    });
    _saveCartDraft();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} زیادکرا بۆ پسوڵە (بڕ: $currentQty)'),
        backgroundColor: AppColors.success,
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  Future<void> _confirmDeleteCartItem(PurchaseCartItem item) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی کاڵا',
      message: 'ئایا دڵنیایت لە سڕینەوەی «${item.product.name}» لە پسوڵەی کڕین؟',
      confirmText: 'بەڵێ، بسڕەوە',
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      _deleteCartItem(item);
    }
  }

  void _removeFromCart(PurchaseCartItem item) {
    if (item.quantity > 1) {
      setState(() {
        item.quantity -= 1;
        _updatePaidAmountToTotal();
      });
      _saveCartDraft();
    } else {
      _confirmDeleteCartItem(item);
    }
  }

  void _deleteCartItem(PurchaseCartItem item) {
    setState(() {
      _purchaseCart.remove(item);
      _updatePaidAmountToTotal();
    });
    _saveCartDraft();
  }

  void _showItemConfigDialog(PurchaseCartItem item) {
    final qtyController = TextEditingController(text: item.quantity.toString());
    final cartonQtyController = TextEditingController(text: item.quantity.toString());
    final contentValController = TextEditingController(text: item.cartonContentValue.toString());
    final costController = TextEditingController(text: item.unitCost.toInt().toString());

    PurchaseUnitType selectedUnitType = item.unitType;
    CartonContentMode selectedCartonMode = item.cartonContentMode;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final currentCartonQty = int.tryParse(cartonQtyController.text) ?? 1;
            final currentContentVal = int.tryParse(contentValController.text) ?? 1;

            int computedUnitsPerCarton;
            if (selectedCartonMode == CartonContentMode.byUnit) {
              computedUnitsPerCarton = currentContentVal > 0 ? currentContentVal : 1;
            } else {
              final p = item.piecesPerUnit;
              computedUnitsPerCarton = (currentContentVal / p).round();
              if (computedUnitsPerCarton <= 0) computedUnitsPerCarton = 1;
            }
            final computedTotalStock = currentCartonQty * computedUnitsPerCarton;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with close button at TOP-LEFT (Rules compliant)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'داخستن',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'دەستکاری کڕینی ${item.product.name}',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),

                      // Unit Type toggle
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedUnitType = PurchaseUnitType.baseUnit;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedUnitType == PurchaseUnitType.baseUnit
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedUnitType == PurchaseUnitType.baseUnit
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'یەکە (${item.baseUnitName})',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: selectedUnitType == PurchaseUnitType.baseUnit
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedUnitType = PurchaseUnitType.carton;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedUnitType == PurchaseUnitType.carton
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedUnitType == PurchaseUnitType.carton
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'کارتۆن',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: selectedUnitType == PurchaseUnitType.carton
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (selectedUnitType == PurchaseUnitType.baseUnit) ...[
                        AppTextField(
                          controller: qtyController,
                          labelText: 'بڕی یەکە (${item.baseUnitName})',
                          keyboardType: TextInputType.number,
                        ),
                      ] else ...[
                        // Carton Mode inputs
                        AppTextField(
                          controller: cartonQtyController,
                          labelText: 'بڕی کارتۆن (چەند کارتۆن کڕاوە)',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Text(
                          'ناوەڕۆکی کارتۆن بە چی هەژمار دەکرێت؟',
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedCartonMode = CartonContentMode.byUnit;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: selectedCartonMode == CartonContentMode.byUnit
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedCartonMode == CartonContentMode.byUnit
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        selectedCartonMode == CartonContentMode.byUnit
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 18,
                                        color: selectedCartonMode == CartonContentMode.byUnit
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'یەکە (${item.baseUnitName})',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: selectedCartonMode == CartonContentMode.byUnit
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedCartonMode = CartonContentMode.byPieces;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: selectedCartonMode == CartonContentMode.byPieces
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedCartonMode == CartonContentMode.byPieces
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        selectedCartonMode == CartonContentMode.byPieces
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 18,
                                        color: selectedCartonMode == CartonContentMode.byPieces
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'دانە',
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: selectedCartonMode == CartonContentMode.byPieces
                                             ? theme.colorScheme.primary
                                             : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        AppTextField(
                          controller: contentValController,
                          labelText: selectedCartonMode == CartonContentMode.byUnit
                              ? 'ژمارەی یەکە (${item.baseUnitName}) لە هەر کارتۆنێک'
                              : 'ژمارەی دانە لە هەر کارتۆنێک (بۆ نمونە: ١٢٠ دانە)',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, size: 20, color: AppColors.info),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  selectedCartonMode == CartonContentMode.byPieces
                                      ? 'هەر کارتۆنێک = $computedUnitsPerCarton ${item.baseUnitName} ($currentContentVal دانە ÷ ${item.piecesPerUnit})\nکۆی ستۆکی زیادکراو = $computedTotalStock ${item.baseUnitName}'
                                      : 'هەر کارتۆنێک = $currentContentVal ${item.baseUnitName}\nکۆی ستۆکی زیادکراو = $computedTotalStock ${item.baseUnitName}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: costController,
                        labelText: 'تێچووی یەکەی کاڵا (${item.baseUnitName}) - د.ع',
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      // Primary action button only
                      AppButton(
                        text: 'پاشەکەوتکردن',
                        onPressed: () {
                          final parsedQty = selectedUnitType == PurchaseUnitType.baseUnit
                              ? (int.tryParse(qtyController.text) ?? 1)
                              : (int.tryParse(cartonQtyController.text) ?? 1);
                          final parsedContent = int.tryParse(contentValController.text) ?? 1;
                          final parsedCost = double.tryParse(costController.text) ?? item.unitCost;

                          setState(() {
                            item.unitType = selectedUnitType;
                            item.cartonContentMode = selectedCartonMode;
                            item.quantity = parsedQty > 0 ? parsedQty : 1;
                            item.cartonContentValue = parsedContent > 0 ? parsedContent : 1;
                            item.unitCost = parsedCost >= 0 ? parsedCost : item.unitCost;
                            _updatePaidAmountToTotal();
                          });
                          _saveCartDraft();

                          Navigator.pop(ctx);
                        },
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

  void _scanBarcode(List<ProductModel> allProducts) {
    CameraBarcodeScanner.show(
      context,
      (barcode) {
        final found = allProducts.where((p) => p.barcode == barcode.trim()).firstOrNull;
        if (found != null) {
          _addProductToCart(found);
        } else {
          AppSnackbar.show(
            context,
            message: 'هیچ کاڵایەک بەم باڕکۆدە ($barcode) نەدۆزرایەوە',
            type: SnackbarType.warning,
          );
        }
      },
      closeOnScan: true,
    );
  }

  void _addCheckedProductsToCart(List<ProductModel> products) {
    int addedCount = 0;
    for (final prod in products) {
      if (_checkedProductIds.contains(prod.id)) {
        final existingIndex = _purchaseCart.indexWhere((item) => item.product.id == prod.id);
        final suggestedQty = prod.minStockLevel > prod.totalStock
            ? (prod.minStockLevel - prod.totalStock)
            : 10;
        final qtyToAdd = suggestedQty > 0 ? suggestedQty : 1;

        if (existingIndex >= 0) {
          _purchaseCart[existingIndex].quantity += qtyToAdd;
        } else {
          _purchaseCart.add(PurchaseCartItem(
            product: prod,
            quantity: qtyToAdd,
          ));
        }
        addedCount++;
      }
    }
    if (addedCount > 0) {
      _checkedProductIds.clear();
      _updatePaidAmountToTotal();
      _saveCartDraft();
      AppSnackbar.show(
        context,
        message: '$addedCount کاڵا زیادکران بۆ سەبەتەی کڕین',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _submitPurchaseInvoice() async {
    if (_isSubmittingPO) return;
    if (_purchaseCart.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'سەبەتەی کڕین بەتاڵە! لانیکەم یەک کاڵا زیاد بکە',
        type: SnackbarType.warning,
      );
      return;
    }

    final warehousesAsync = ref.read(warehouseListProvider);
    final warehouses = warehousesAsync.asData?.value ?? [];
    final warehouseId = _selectedWarehouseId ??
        (warehouses.any((w) => (w as dynamic).isMain == true)
            ? (warehouses.firstWhere((w) => (w as dynamic).isMain == true) as dynamic).id
            : (warehouses.isNotEmpty ? (warehouses.first as dynamic).id : 1));

    final totalAmount = _calculateCartTotal();
    final textVal = _poPaidAmountController.text.trim();
    final parsedPaid = double.tryParse(textVal);
    final paidAmount = parsedPaid ?? (_userModifiedPaidAmount ? 0.0 : totalAmount);

    final itemsPayload = _purchaseCart.map((item) {
      return {
        'product_id': item.product.id,
        'quantity': item.totalStockUnits,
        'unit_cost': item.effectiveUnitCostForServer,
      };
    }).toList();

    setState(() => _isSubmittingPO = true);
    try {
      PurchaseOrderModel order;
      if (_activeDraftOrderId != null) {
        order = await ref.read(purchaseActionsProvider).updatePurchaseOrder(
              orderId: _activeDraftOrderId!,
              supplierId: _selectedSupplierId,
              warehouseId: warehouseId,
              items: itemsPayload,
              paidAmount: paidAmount,
              autoReceive: true,
              notes: _poNotesController.text.trim().isEmpty ? null : _poNotesController.text.trim(),
            );
      } else {
        order = await ref.read(purchaseActionsProvider).createPurchaseOrder(
              supplierId: _selectedSupplierId,
              warehouseId: warehouseId,
              items: itemsPayload,
              paidAmount: paidAmount,
              autoReceive: true,
              notes: _poNotesController.text.trim().isEmpty ? null : _poNotesController.text.trim(),
            );
      }

      if (mounted) {
        setState(() {
          _activeDraftOrderId = null;
          _lastLoadedDraftOrderId = null;
          _purchaseCart.clear();
          _poNotesController.clear();
          _poPaidAmountController.text = '0';
          _checkedProductIds.clear();
          _userModifiedPaidAmount = false;
        });
        _clearCartDraft();

        final remainingDebt = order.remainingDebt;
        final debtMsg = remainingDebt > 0
            ? ' (قەرزی ماوە بۆ دابینکەر: ${Formatters.currency(remainingDebt)} د.ع)'
            : ' (تەواوی بڕی پسوڵە درا)';

        AppSnackbar.show(
          context,
          message: 'پسوڵەی کڕین #${order.orderNumber} بەسەرکەوتوویی تەئکید کرایەوە و تۆمارکرا$debtMsg',
          type: SnackbarType.success,
        );

        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPO = false);
    }
  }

  void _showMoveItemDialog(
    PurchaseCartItem item,
    List<PurchaseOrderModel> draftOrders,
    List<dynamic> warehouses,
    List<ProductModel> allProducts,
  ) {
    final otherDrafts = draftOrders.where((d) => d.id != _activeDraftOrderId).toList();
    int? targetDraftId = otherDrafts.isNotEmpty ? otherDrafts.first.id : null;
    bool isCreateNew = otherDrafts.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('گواستنەوەی کاڵا بۆ پسوڵەیەکی تر', style: AppTextStyles.h2.copyWith(fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: min(MediaQuery.of(context).size.width * 0.9, 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.product.name} (بڕ: ${item.quantity} ${item.unitType == PurchaseUnitType.carton ? "کارتۆن" : item.baseUnitName})',
                                style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (otherDrafts.isNotEmpty) ...[
                        RadioListTile<bool>(
                          title: const Text('گواستنەوە بۆ پسوڵەیەکی کراوەی تر:'),
                          value: false,
                          groupValue: isCreateNew,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setDlgState(() => isCreateNew = false),
                        ),
                        if (!isCreateNew)
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: targetDraftId,
                                isExpanded: true,
                                items: otherDrafts.map((d) {
                                  final sName = d.supplierName.isNotEmpty ? d.supplierName : 'بێناو';
                                  return DropdownMenuItem<int>(
                                    value: d.id,
                                    child: Text('#${d.orderNumber} ($sName) • ${d.items.length} کاڵا'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() => targetDraftId = val);
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                      RadioListTile<bool>(
                        title: const Text('دروستکردنی پسوڵەی نوێ بۆ ئەم کاڵایە'),
                        value: true,
                        groupValue: isCreateNew,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDlgState(() => isCreateNew = true),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                AppButton(
                  text: 'گواستنەوەی کاڵا',
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _executeMoveItem(item, isCreateNew, targetDraftId, otherDrafts, warehouses, allProducts);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeMoveItem(
    PurchaseCartItem item,
    bool isCreateNew,
    int? targetDraftId,
    List<PurchaseOrderModel> otherDrafts,
    List<dynamic> warehouses,
    List<ProductModel> allProducts,
  ) async {
    try {
      setState(() {
        _purchaseCart.removeWhere((i) => i.product.id == item.product.id);
        _updatePaidAmountToTotal();
      });
      await _saveCartDraft(forceSaveToBackend: true);

      final defaultWhId = _selectedWarehouseId ??
          (warehouses.any((w) => (w as dynamic).isMain == true)
              ? (warehouses.firstWhere((w) => (w as dynamic).isMain == true) as dynamic).id
              : (warehouses.isNotEmpty ? (warehouses.first as dynamic).id : 1));

      if (isCreateNew) {
        final newOrder = await ref.read(purchaseActionsProvider).createPurchaseOrder(
          supplierId: item.product.supplierId ?? _selectedSupplierId,
          warehouseId: defaultWhId,
          items: [
            {
              'product_id': item.product.id,
              'quantity': item.totalStockUnits,
              'unit_cost': item.effectiveUnitCostForServer,
            }
          ],
          autoReceive: false,
        );
        ref.invalidate(purchaseOrdersProvider);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کاڵای «${item.product.name}» گوازرایەوە بۆ پسوڵەی نوێ #${newOrder.orderNumber}',
            type: SnackbarType.success,
          );
        }
      } else if (targetDraftId != null) {
        final targetDraft = otherDrafts.firstWhere((d) => d.id == targetDraftId);
        final updatedItems = targetDraft.items.map((it) => {
          'product_id': it.productId,
          'quantity': it.quantity,
          'unit_cost': it.unitCost.toInt(),
        }).toList();

        final existingIdx = updatedItems.indexWhere((it) => it['product_id'] == item.product.id);
        if (existingIdx >= 0) {
          updatedItems[existingIdx]['quantity'] = (updatedItems[existingIdx]['quantity'] as int) + item.totalStockUnits;
        } else {
          updatedItems.add({
            'product_id': item.product.id,
            'quantity': item.totalStockUnits,
            'unit_cost': item.effectiveUnitCostForServer,
          });
        }

        await ref.read(purchaseActionsProvider).updatePurchaseOrder(
          orderId: targetDraft.id,
          items: updatedItems,
        );

        ref.invalidate(purchaseOrdersProvider);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کاڵای «${item.product.name}» گوازرایەوە بۆ پسوڵەی #${targetDraft.orderNumber}',
            type: SnackbarType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'کێشە لە گواستنەوەی کاڵا: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _showSupplierLowStockDialog(
    BuildContext context,
    List<ProductModel> allProducts,
    List<SupplierModel> suppliers,
  ) {
    int? currentSupplierFilter = _selectedSupplierId;
    final TextEditingController thresholdController = TextEditingController(text: '10');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final threshold = int.tryParse(thresholdController.text.trim()) ?? 10;

            var filtered = allProducts.where((p) {
              final matchSupplier = currentSupplierFilter == null || p.supplierId == currentSupplierFilter;
              final matchStock = p.totalStock < threshold;
              return matchSupplier && matchStock;
            }).toList();

            // ڕیزکردن بەپێی بچووکترین ستۆک بۆ گەورەترین
            filtered.sort((a, b) => a.totalStock.compareTo(b.totalStock));

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'کاڵاکانی دابینکەر (کەمیی ستۆک)',
                          style: AppTextStyles.h2.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: min(MediaQuery.of(context).size.width * 0.95, 550),
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // فلتەری هەڵبژاردنی دابینکەر
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: currentSupplierFilter,
                          isExpanded: true,
                          hint: const Text('هەموو دابینکەرەکان'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.people_alt_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('هەموو دابینکەرەکان'),
                                ],
                              ),
                            ),
                            ...suppliers.map((s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.business_outlined, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              currentSupplierFilter = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // فلتەری ستۆکی کەمتر لە ئینپوتێک
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'نیشاندانی ستۆکی کەمتر لە:',
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          height: 38,
                          child: TextField(
                            controller: thresholdController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 6),

                    // لیستی کاڵاکان بەپێی کەمترین ستۆک
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 48, color: AppColors.success.withValues(alpha: 0.7)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'هیچ کاڵایەک ستۆکی کەمتر لە $threshold نییە',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final prod = filtered[i];
                                final unitStr = prod.unit?.trim().isNotEmpty == true ? prod.unit! : 'دانە';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prod.name,
                                              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'تێچوو: ${Formatters.currency(prod.costPrice)} • بارکۆد: ${prod.barcode}',
                                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(
                                        label: 'مەوجود: ${prod.totalStock} $unitStr',
                                        type: prod.totalStock <= 0 ? StatusBadgeType.danger : StatusBadgeType.warning,
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                                        tooltip: 'زیادکردن بۆ پسوڵە',
                                        onPressed: () {
                                          _showAddLowStockProductToCartDialog(prod);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
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
  }

  void _showAddLowStockProductToCartDialog(ProductModel product) {
    PurchaseUnitType selectedUnitType = PurchaseUnitType.baseUnit;
    CartonContentMode selectedCartonMode = CartonContentMode.byUnit;
    final TextEditingController qtyController = TextEditingController(text: '1');
    final TextEditingController cartonQtyController = TextEditingController(text: '1');
    final TextEditingController contentValController = TextEditingController(
      text: product.unitsPerCarton > 0 ? product.unitsPerCarton.toString() : '10',
    );
    final TextEditingController costController = TextEditingController(
      text: product.costPrice.toInt().toString(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final parsedContentVal = int.tryParse(contentValController.text) ?? 1;
            final int currentContentVal = parsedContentVal > 0 ? parsedContentVal : 1;
            final int piecesPerUnit = product.unitsPerCarton > 0 ? product.unitsPerCarton : 1;

            int computedUnitsPerCarton;
            if (selectedCartonMode == CartonContentMode.byUnit) {
              computedUnitsPerCarton = currentContentVal;
            } else {
              final val = (currentContentVal / piecesPerUnit).round();
              computedUnitsPerCarton = val > 0 ? val : 1;
            }

            final parsedQty = selectedUnitType == PurchaseUnitType.baseUnit
                ? (int.tryParse(qtyController.text) ?? 1)
                : (int.tryParse(cartonQtyController.text) ?? 1);
            final int safeQty = parsedQty > 0 ? parsedQty : 1;
            final int computedTotalStock = selectedUnitType == PurchaseUnitType.baseUnit
                ? safeQty
                : safeQty * computedUnitsPerCarton;

            final parsedCost = double.tryParse(costController.text) ?? product.costPrice;
            final double computedTotalCost = computedTotalStock * parsedCost;
            final unitName = product.unit?.trim().isNotEmpty == true ? product.unit! : 'دانە';

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'زیادکردنی ${product.name}',
                      style: AppTextStyles.h2.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: min(MediaQuery.of(context).size.width * 0.9, 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedUnitType = PurchaseUnitType.baseUnit;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: selectedUnitType == PurchaseUnitType.baseUnit
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedUnitType == PurchaseUnitType.baseUnit
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'بە یەکە ($unitName)',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: selectedUnitType == PurchaseUnitType.baseUnit
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedUnitType = PurchaseUnitType.carton;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: selectedUnitType == PurchaseUnitType.carton
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedUnitType == PurchaseUnitType.carton
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'بە کارتۆن',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: selectedUnitType == PurchaseUnitType.carton
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (selectedUnitType == PurchaseUnitType.baseUnit) ...[
                        AppTextField(
                          controller: qtyController,
                          labelText: 'بڕی کڕین بە یەکە ($unitName)',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ] else ...[
                        AppTextField(
                          controller: cartonQtyController,
                          labelText: 'ژمارەی کارتۆن',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: contentValController,
                          labelText: 'ژمارەی یەکە ($unitName) لە هەر کارتۆنێک',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: costController,
                        labelText: 'نرخی تێچووی یەکە ($unitName) - د.ع',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'کۆی ستۆکی زیادکراو: $computedTotalStock $unitName',
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'کۆی نرخی ئەم کاڵایە: ${Formatters.currency(computedTotalCost)} د.ع',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                AppButton(
                  text: 'زیادکردن بۆ پسوڵە',
                  onPressed: () {
                    final parsedItemCost = double.tryParse(costController.text) ?? product.costPrice;

                    setState(() {
                      final existingIndex = _purchaseCart.indexWhere((it) => it.product.id == product.id);
                      if (existingIndex >= 0) {
                        _purchaseCart[existingIndex].quantity += safeQty;
                        _purchaseCart[existingIndex].unitCost = parsedItemCost;
                        _purchaseCart[existingIndex].unitType = selectedUnitType;
                        _purchaseCart[existingIndex].cartonContentValue = currentContentVal;
                      } else {
                        _purchaseCart.add(PurchaseCartItem(
                          product: product,
                          unitType: selectedUnitType,
                          cartonContentMode: selectedCartonMode,
                          quantity: safeQty,
                          cartonContentValue: currentContentVal,
                          unitCost: parsedItemCost,
                        ));
                      }
                      _updatePaidAmountToTotal();
                    });

                    _saveCartDraft(forceSaveToBackend: true);
                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('«${product.name}» زیادکرا بۆ پسوڵەی کڕین'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPurchasesTab(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsListProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final posAsync = ref.watch(purchaseOrdersProvider);
    final allOrders = posAsync.asData?.value ?? [];
    final draftOrders = allOrders.where((o) => o.status.toUpperCase() == 'DRAFT').toList();

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('هەڵە لە بارکردنی کاڵاکان: $err', style: AppTextStyles.bodyMedium),
      ),
      data: (allProducts) {
        if (!_hasRestoredDraft) {
          _hasRestoredDraft = true;
          if (_activeDraftOrderId == null && draftOrders.isNotEmpty) {
            final firstDraft = draftOrders.first;
            _activeDraftOrderId = firstDraft.id;
            _lastLoadedDraftOrderId = firstDraft.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadDraftOrderData(firstDraft, allProducts);
                setState(() {});
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _restoreCartDraft(allProducts);
              }
            });
          }
        }
        // Find products that need purchasing (totalStock <= minStockLevel or stock <= 0)
        final lowStockProducts = allProducts.where((p) {
          if (p.minStockLevel > 0) {
            return p.totalStock <= p.minStockLevel;
          }
          return p.totalStock <= 0;
        }).toList();

        List<ProductModel> filteredLowStock;
        if (_lowStockFilter == 'checked') {
          filteredLowStock = lowStockProducts.where((p) => _checkedProductIds.contains(p.id)).toList();
        } else if (_lowStockFilter == 'unchecked') {
          filteredLowStock = lowStockProducts.where((p) => !_checkedProductIds.contains(p.id)).toList();
        } else {
          filteredLowStock = lowStockProducts;
        }

        final suppliers = suppliersAsync.asData?.value ?? [];
        final warehouses = warehousesAsync.asData?.value ?? [];

        final totalAmount = _calculateCartTotal();
        final textVal = _poPaidAmountController.text.trim();
        final parsedPaid = double.tryParse(textVal);
        final paidAmount = parsedPaid ?? (_userModifiedPaidAmount ? 0.0 : totalAmount);
        final remainingDebt = max(0.0, totalAmount - paidAmount);

        return Column(
          children: [
            // Section 1: Note/Notice of Low Stock / Needed Products (کەمی ستۆک / پێویست بۆ کڕین)
            if (lowStockProducts.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isLowStockExpanded = !_isLowStockExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'تێبینی: ${lowStockProducts.length} کاڵا گەیشتوونەتە کەمترین بڕی ستۆک و پێویستن بۆ کڕین',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              _isLowStockExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isLowStockExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Filter Chips
                              ChoiceChip(
                                label: Text('هەموو (${lowStockProducts.length})', style: const TextStyle(fontSize: 11)),
                                selected: _lowStockFilter == 'all',
                                onSelected: (_) => setState(() => _lowStockFilter = 'all'),
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: Text('چێککراو (${_checkedProductIds.length})', style: const TextStyle(fontSize: 11)),
                                selected: _lowStockFilter == 'checked',
                                onSelected: (_) => setState(() => _lowStockFilter = 'checked'),
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: Text('چێکنەکراو (${lowStockProducts.length - _checkedProductIds.length})', style: const TextStyle(fontSize: 11)),
                                selected: _lowStockFilter == 'unchecked',
                                onSelected: (_) => setState(() => _lowStockFilter = 'unchecked'),
                              ),
                              if (_checkedProductIds.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                                  label: Text(
                                    'زیادکردن بۆ سەبەتە (${_checkedProductIds.length})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _addCheckedProductsToCart(lowStockProducts),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                          itemCount: filteredLowStock.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prod = filteredLowStock[index];
                            final isChecked = _checkedProductIds.contains(prod.id);
                            final unitStr = prod.unit?.trim().isNotEmpty == true ? prod.unit! : 'دانە';

                            return Row(
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _checkedProductIds.add(prod.id);
                                      } else {
                                        _checkedProductIds.remove(prod.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        prod.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'کەمترین بڕی ستۆک: ${prod.minStockLevel} • بارکۆد: ${prod.barcode}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: 'مەوجود: ${prod.totalStock} $unitStr',
                                  type: prod.totalStock <= 0 ? StatusBadgeType.danger : StatusBadgeType.warning,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  tooltip: 'زیادکردن بۆ سەبەتە',
                                  onPressed: () => _addProductToCart(prod),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Section 2: Top Control Bar (Draft Invoices Selector + Supplier selection + Add Supplier + Warehouse + Notes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 0: Draft Invoices Selector Bar (درۆپداونی پسوڵەکان)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'پسوڵەکان:',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _activeDraftOrderId,
                              isExpanded: true,
                              hint: const Text('پسوڵەی کڕینی نوێ'),
                              items: [
                                if (_activeDraftOrderId == null || !draftOrders.any((d) => d.id == _activeDraftOrderId))
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('پسوڵەی نوێ (دەستپێکردن)'),
                                  ),
                                ...draftOrders.map((d) {
                                  final sName = d.supplierName.isNotEmpty ? d.supplierName : 'بێناو';
                                  return DropdownMenuItem<int?>(
                                    value: d.id,
                                    child: Text(
                                      '#${d.orderNumber} ($sName) • ${d.items.length} کاڵا',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _switchDraftOrder(val, draftOrders, allProducts);
                                }
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                          tooltip: 'دروستکردنی پسوڵەی نوێ',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _createNewDraftInvoice(warehouses),
                        ),
                        if (_activeDraftOrderId != null) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            tooltip: 'سڕینەوەی ئەم پسوڵەیە لە داتابەیس',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _deleteCurrentDraftOrder(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      // Supplier selection dropdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedSupplierId,
                              isExpanded: true,
                              hint: const Text('دابینکەری نوێ (بێناو)'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text('دابینکەری نوێ (بێناو)'),
                                    ],
                                  ),
                                ),
                                ...suppliers.map((s) => DropdownMenuItem<int?>(
                                      value: s.id,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.business_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${s.name}${s.debt > 0 ? " (قەرز: ${Formatters.currency(s.debt)})" : ""}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedSupplierId = val;
                                });
                                _saveCartDraft();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // (+) Add Supplier icon button
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
                        tooltip: 'زیادکردنی دابینکەری نوێ',
                        onPressed: () {
                          _showAddSupplierDialog(context);
                        },
                      ),
                      const SizedBox(width: 4),

                      // Warehouse selector dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedWarehouseId ??
                                  (warehouses.any((w) => (w as dynamic).isMain == true)
                                      ? (warehouses.firstWhere((w) => (w as dynamic).isMain == true) as dynamic).id
                                      : (warehouses.isNotEmpty ? (warehouses.first as dynamic).id : 1)),
                              isExpanded: true,
                              items: warehouses.map((w) {
                                return DropdownMenuItem<int>(
                                  value: (w as dynamic).id as int,
                                  child: Text((w as dynamic).name as String, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedWarehouseId = val;
                                  });
                                  _saveCartDraft();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Notes text field
                  AppTextField(
                    controller: _poNotesController,
                    hintText: 'تێبینی پسوڵەی کڕین...',
                    prefixIcon: Icons.note_alt_outlined,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),

            // Section 3: Product Search Bar & Barcode Scanner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
              child: RawAutocomplete<ProductModel>(
                textEditingController: _productSearchController,
                focusNode: _productSearchFocusNode,
                displayStringForOption: (ProductModel option) => option.name,
                onSelected: (ProductModel selection) {
                  _addProductToCart(selection, clearSearch: true);
                  _productSearchFocusNode.unfocus();
                },
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<ProductModel>.empty();
                  }
                  final query = textEditingValue.text.toLowerCase().trim();
                  return allProducts.where((p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.barcode.toLowerCase().contains(query) ||
                      (p.sku != null && p.sku!.toLowerCase().contains(query)));
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return GestureDetector(
                    onLongPress: () {
                      _showSupplierLowStockDialog(context, allProducts, suppliers);
                    },
                    child: AppTextField(
                      controller: controller,
                      focusNode: focusNode,
                      hintText: 'گەڕان بەپێی ناوی کاڵا یان بارکۆد (لۆنگ پرێس: کاڵاکانی دابینکەر)...',
                      prefixIcon: Icons.search,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.inventory_2_outlined, size: 20),
                            tooltip: 'کاڵاکانی دابینکەر بەپێی کەمیی ستۆک (لۆنگ پرێس)',
                            onPressed: () => _showSupplierLowStockDialog(context, allProducts, suppliers),
                          ),
                          if (controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                controller.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'سکانی باڕکۆد',
                            onPressed: () => _scanBarcode(allProducts),
                          ),
                        ],
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return TapRegion(
                    groupId: _productSearchFocusNode,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Material(
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          color: theme.colorScheme.surface,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - (AppSpacing.sm * 2),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final prod = options.elementAt(index);
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _addProductToCart(prod, clearSearch: true);
                                        _productSearchFocusNode.unfocus();
                                      },
                                      onLongPress: () {
                                        _addProductToCart(prod, clearSearch: false);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.add_shopping_cart, size: 20),
                                              tooltip: 'زیادکردن (بێ لانەچوونی لیستەکە)',
                                              onPressed: () {
                                                _addProductToCart(prod, clearSearch: false);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    prod.name,
                                                    style: AppTextStyles.bodyBold,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'تێچوو: ${Formatters.currency(prod.costPrice)} • ستۆک: ${prod.totalStock} ${prod.unit ?? "دانە"}',
                                                    style: AppTextStyles.caption,
                                                  ),
                                                ],
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
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Section 4: Cart Items List
            if (_purchaseCart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'کاڵاکانی پسوڵە (${_purchaseCart.length})',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('سڕینەوەی هەمووی', style: TextStyle(fontSize: 12)),
                      onPressed: _clearEntireCart,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _purchaseCart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'سەبەتەی کڕین بەتاڵە',
                            style: AppTextStyles.h3.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'کاڵاکان لە بەشی گەڕان یان لە بەشی کەمی ستۆکی سەرەوە زیاد بکە',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: _purchaseCart.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final item = _purchaseCart[index];
                        final isCarton = item.unitType == PurchaseUnitType.carton;

                        return InkWell(
                          onTap: () => _showItemConfigDialog(item),
                          onLongPress: () => _confirmDeleteCartItem(item),
                          borderRadius: BorderRadius.circular(10),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Thumbnail + Product Name + Stepper
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.inventory_2_outlined, size: 18, color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        item.product.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.drive_file_move_outlined, size: 18, color: AppColors.primary),
                                      tooltip: 'گواستنەوە بۆ پسوڵەیەکی تر',
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () => _showMoveItemDialog(item, draftOrders, warehouses, allProducts),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    // Stepper: [+] [qty] [-]
                                    Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            tooltip: 'زیادکردن',
                                            onPressed: () {
                                              setState(() {
                                                item.quantity += 1;
                                                _updatePaidAmountToTotal();
                                              });
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '${item.quantity}',
                                              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            tooltip: 'کەمکردنەوە',
                                            onPressed: () => _removeFromCart(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Second row: Unit Badge + Unit Cost + Line Total Cost
                                SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => _showItemConfigDialog(item),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isCarton
                                                    ? AppColors.purple.withValues(alpha: 0.15)
                                                    : theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isCarton ? AppColors.purple : theme.colorScheme.outlineVariant,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isCarton ? Icons.all_inbox_outlined : Icons.straighten,
                                                    size: 13,
                                                    color: isCarton ? AppColors.purple : theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isCarton
                                                        ? 'کارتۆن (${item.quantity} کارتۆن = ${item.totalStockUnits} ${item.baseUnitName})'
                                                        : 'یەکە: ${item.baseUnitName}',
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: isCarton ? AppColors.purple : null,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 11,
                                                    color: isCarton ? AppColors.purple : theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'تێچوو: ${Formatters.currency(item.unitCost)}',
                                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'کۆی گشتی دێڕ: ',
                                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                                          ),
                                          Text(
                                            Formatters.currency(item.totalLineCost),
                                            style: AppTextStyles.bodyBold.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Section 5: Bottom Summary Bar (Total Amount + Paid Amount + Debt + Confirm Button)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Financial Summary: Total, Paid Amount, Remaining Debt
                    Row(
                      children: [
                        // Total
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('کۆی پسوڵە:', style: AppTextStyles.caption),
                                Text(
                                  Formatters.currency(totalAmount),
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),

                        // Paid Amount field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('بڕی پارەی دراو:', style: AppTextStyles.caption),
                                TextField(
                                  controller: _poPaidAmountController,
                                  keyboardType: TextInputType.number,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 15,
                                    color: theme.colorScheme.primary,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0',
                                  ),
                                  onChanged: (_) {
                                    _userModifiedPaidAmount = true;
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),

                        // Remaining Debt
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: remainingDebt > 0
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: remainingDebt > 0
                                  ? Border.all(color: AppColors.warning.withValues(alpha: 0.35))
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('قەرزی ماوە:', style: AppTextStyles.caption),
                                Text(
                                  Formatters.currency(remainingDebt),
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: remainingDebt > 0 ? AppColors.warning : theme.colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Confirm Purchase Button
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'تەئکیدکردنەوە و تۆمارکردنی پسوڵە',
                        isLoading: _isSubmittingPO,
                        onPressed: _purchaseCart.isEmpty ? null : _submitPurchaseInvoice,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPurchaseOrdersTab(BuildContext context) {
    final posAsync = ref.watch(purchaseOrdersProvider);
    final theme = Theme.of(context);

    return posAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('کێشەیەک لە بارکردنی پسوڵەکان دروستبوو'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(purchaseOrdersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'هیچ پسوڵەیەکی کڕین تۆمار نەکراوە',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: orders.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.status.toUpperCase();
              final isDraft = status == 'DRAFT';
              final isConfirmed = status == 'CONFIRMED';
              final isReceived = status == 'RECEIVED';
              final isCancelled = status == 'CANCELLED';

              String badgeLabel = 'ڕەشنووس';
              StatusBadgeType badgeType = StatusBadgeType.warning;
              if (isConfirmed) {
                badgeLabel = 'پەسەندکراوە';
                badgeType = StatusBadgeType.info;
              } else if (isReceived) {
                badgeLabel = 'وەرگیراوە';
                badgeType = StatusBadgeType.success;
              } else if (isCancelled) {
                badgeLabel = 'هەڵوەشاوە';
                badgeType = StatusBadgeType.danger;
              }

              return AppCard(
                onTap: isDraft
                    ? () {
                        final allProducts = ref.read(productsListProvider).valueOrNull ?? [];
                        _switchDraftOrder(order.id, orders, allProducts);
                        _tabController.animateTo(0);
                      }
                    : (isConfirmed ? () => _receivePO(order) : null),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isReceived
                        ? AppColors.success.withValues(alpha: 0.1)
                        : (isConfirmed
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest),
                    child: Icon(
                      AppIcons.order,
                      color: isReceived
                          ? AppColors.success
                          : theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'پسوڵەی کڕین #${order.orderNumber}',
                    style: AppTextStyles.bodyBold,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.supplierName} • ${order.itemsCount} کاڵا • کۆ: ${_formatCurrency(order.totalAmount)}'
                        '${order.paidAmount > 0 ? " • دراوە: ${_formatCurrency(order.paidAmount)}" : ""}'
                        '${order.remainingDebt > 0 ? " • ماوە (قەرز): ${_formatCurrency(order.remainingDebt)}" : ""}',
                        style: AppTextStyles.caption,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => ReceiptPrintService.show(
                            context,
                            ReceiptData.fromPurchaseOrder(
                              order,
                              employee: ref.read(authProvider).user,
                            ),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: const Text('وێنەی پسوڵە'),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: badgeLabel,
                        type: badgeType,
                      ),
                      if (isDraft) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: AppColors.primary),
                          tooltip: 'کردنەوە و دەستکاریکردن لە بەشی کڕین',
                          onPressed: () {
                            final allProducts = ref.read(productsListProvider).valueOrNull ?? [];
                            _switchDraftOrder(order.id, orders, allProducts);
                            _tabController.animateTo(0);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                          tooltip: 'پەسەندکردن و وەرگرتنی پسوڵە',
                          onPressed: () => _confirmPO(order),
                        ),
                      ],
                      if (isConfirmed)
                        IconButton(
                          icon: const Icon(Icons.download_done, color: AppColors.success),
                          tooltip: 'وەرگرتن',
                          onPressed: () => _receivePO(order),
                        ),
                      if (isDraft || isConfirmed)
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                          tooltip: 'هەڵوەشاندنەوە',
                          onPressed: () => _cancelPO(order),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(suppliersListProvider),
      child: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'هیچ کۆمپانیایەک نییە',
                          style: AppTextStyles.bodyBold,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => _showAddSupplierDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('زیادکردنی کۆمپانیا'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final screenWidth = MediaQuery.of(context).size.width;
          int crossAxisCount = 1;
          if (screenWidth >= 1024) {
            crossAxisCount = 3;
          } else if (screenWidth >= 600) {
            crossAxisCount = 2;
          }

          final bool isMobileOrTablet = screenWidth < AppBreakpoints.desktopMin;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: suppliers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.sm,
              mainAxisExtent: isMobileOrTablet ? 124 : 82,
            ),
            itemBuilder: (context, index) =>
                _buildSupplierCard(
                  context,
                  suppliers[index],
                  isMobileOrTablet: isMobileOrTablet,
                ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Text(
                  'شکست لە هێنانی زانیارییەکان: $error',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Widget _buildSupplierCard(
    BuildContext context,
    SupplierModel supplier, {
    bool isMobileOrTablet = false,
  }) {
    final theme = Theme.of(context);
    final bool hasDebt = supplier.debt > 0;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final canReconcile = user?.hasPermission('users.manage') ?? false;

    final String phoneText =
        (supplier.phone != null && supplier.phone!.trim().isNotEmpty)
            ? supplier.phone!.trim()
            : 'مۆبایل نییە';
    final String addressText =
        (supplier.address != null && supplier.address!.trim().isNotEmpty)
            ? supplier.address!.trim()
            : 'ناونیشان نییە';

    final bool isMobileOrTabletView = isMobileOrTablet ||
        (MediaQuery.of(context).size.width < AppBreakpoints.desktopMin);

    return AppCard(
      onTap: () => _showEditSupplierDialog(context, supplier),
      onLongPress: () => _deleteSupplier(supplier),
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        supplier.name,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (canReconcile)
                      IconButton(
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                SupplierReconciliationDialog(
                                    supplier: supplier),
                          );
                        },
                        tooltip: 'لێکترازانی دارایی',
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'کەسی پەیوەندی: ${supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty ? supplier.contactPerson : '-'}',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isMobileOrTabletView) ...[
                  Text(
                    phoneText,
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    addressText,
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    '$phoneText • $addressText',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'کۆد: #${supplier.id}',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: hasDebt
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(supplier.debt),
                      style: AppTextStyles.bodyBold.copyWith(
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasDebt ? 'قەرزدار' : 'پاکە',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'KJino',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReceivePODialog extends StatefulWidget {
  final PurchaseOrderModel order;
  final PurchaseActions actions;

  const ReceivePODialog({
    super.key,
    required this.order,
    required this.actions,
  });

  @override
  State<ReceivePODialog> createState() => _ReceivePODialogState();
}

class _ReceivePODialogState extends State<ReceivePODialog> {
  final Map<int, TextEditingController> _controllers = {};
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.order.items) {
      final remaining = item.quantity - item.receivedQuantity;
      _controllers[item.id] = TextEditingController(text: remaining.toString());
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'وەرگرتنی پسوڵەی کڕین #${widget.order.orderNumber}',
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دەتوانیت بڕی وەرگیراو بۆ هەر کاڵایەک دەستکاری بکەیت بۆ وەرگرتنی بەشەکی، یان سەرجەمیان وەک خۆی وەرگریت.',
                  style: AppTextStyles.caption,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: AppSpacing.md),
                ...widget.order.items.map((item) {
                  final remaining = item.quantity - item.receivedQuantity;
                  final controller = _controllers[item.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: AppTextStyles.bodyBold,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سەرجەم: ${item.quantity} • وەرگیراو: ${item.receivedQuantity}',
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              'مابووەوە: $remaining',
                              style: AppTextStyles.caption.copyWith(
                                color: remaining > 0 ? AppColors.warning : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          labelText: 'بڕی وەرگیراوی ئەمجارە',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'پێویستە بڕێک بنووسیت';
                            }
                            final qty = int.tryParse(value);
                            if (qty == null) {
                              return 'پێویستە ژمارەی تەواو بێت';
                            }
                            if (qty < 0) {
                              return 'ناتوانرێت بڕی کەمتر لە ٠ بێت';
                            }
                            if (qty > remaining) {
                              return 'ناتوانرێت لە بڕی مابووەوە ($remaining) زیاتر بێت';
                            }
                            return null;
                          },
                        ),
                        const Divider(height: AppSpacing.lg),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitFullReceive,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success.withValues(alpha: 0.1),
            foregroundColor: AppColors.success,
          ),
          child: const Text('وەرگرتنی تەواو'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPartialReceive,
          child: const Text('وەرگرتنی دیاریکراو'),
        ),
      ],
    );
  }

  void _submitFullReceive() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.actions.receivePurchaseOrder(widget.order.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _submitPartialReceive() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      for (var item in widget.order.items) {
        final controller = _controllers[item.id];
        final qty = int.parse(controller!.text);
        if (qty > 0) {
          itemsPayload.add({
            'item_id': item.id,
            'product_id': item.productId,
            'quantity': qty,
          });
        }
      }

      if (itemsPayload.isEmpty) {
        throw Exception('هیچ کاڵایەک هەڵنەبژێردراوە بۆ وەرگرتن (بڕی هەموویان ٠ یە).');
      }

      await widget.actions.receivePurchaseOrder(widget.order.id, items: itemsPayload);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
