import 'dart:math';
import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class AdminPurchasesScreen extends ConsumerStatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  ConsumerState<AdminPurchasesScreen> createState() =>
      _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends ConsumerState<AdminPurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedRequirementIds = {};
  bool _isConverting = false;

  final List<PurchaseCartItem> _purchaseCart = [];
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
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

  void _updatePaidAmountToTotal() {
    final total = _calculateCartTotal();
    _poPaidAmountController.text = total > 0 ? total.toInt().toString() : '0';
    if (mounted) setState(() {});
  }

  void _addProductToCart(ProductModel product) {
    final existingIndex = _purchaseCart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _purchaseCart[existingIndex].quantity += 1;
    } else {
      _purchaseCart.add(PurchaseCartItem(
        product: product,
        quantity: 1,
      ));
    }
    _productSearchController.clear();
    _updatePaidAmountToTotal();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} زیادکرا بۆ سەبەتەی کڕین'),
        backgroundColor: AppColors.success,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _removeFromCart(PurchaseCartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity -= 1;
      } else {
        _purchaseCart.remove(item);
      }
      _updatePaidAmountToTotal();
    });
  }

  void _deleteCartItem(PurchaseCartItem item) {
    setState(() {
      _purchaseCart.remove(item);
      _updatePaidAmountToTotal();
    });
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
                              child: RadioListTile<CartonContentMode>(
                                value: CartonContentMode.byUnit,
                                groupValue: selectedCartonMode,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'یەکە (${item.baseUnitName})',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedCartonMode = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<CartonContentMode>(
                                value: CartonContentMode.byPieces,
                                groupValue: selectedCartonMode,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'دانە',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedCartonMode = val;
                                    });
                                  }
                                },
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
        (warehouses.any((w) => w.isMain)
            ? warehouses.firstWhere((w) => w.isMain).id
            : (warehouses.isNotEmpty ? warehouses.first.id : 1));

    final totalAmount = _calculateCartTotal();
    final paidAmount = double.tryParse(_poPaidAmountController.text.trim()) ?? totalAmount;

    final itemsPayload = _purchaseCart.map((item) {
      return {
        'product_id': item.product.id,
        'quantity': item.totalStockUnits,
        'unit_cost': item.effectiveUnitCostForServer,
      };
    }).toList();

    setState(() => _isSubmittingPO = true);
    try {
      final order = await ref.read(purchaseActionsProvider).createPurchaseOrder(
            supplierId: _selectedSupplierId,
            warehouseId: warehouseId,
            items: itemsPayload,
            paidAmount: paidAmount,
            autoReceive: true,
            notes: _poNotesController.text.trim().isEmpty ? null : _poNotesController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _purchaseCart.clear();
          _poNotesController.clear();
          _poPaidAmountController.clear();
          _checkedProductIds.clear();
        });

        final remainingDebt = order.remainingDebt;
        final debtMsg = remainingDebt > 0
            ? ' (قەرزی ماوە بۆ دابینکەر: ${Formatters.currency(remainingDebt)} د.ع)'
            : ' (تەواوی پسوڵەکە بە نەقد درا)';

        AppSnackbar.show(
          context,
          message: 'پسوڵەی کڕین #${order.orderNumber} بەسەرکەوتوویی دروستکرا و کاڵاکان خرانە ناو ستۆک$debtMsg',
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

  Widget _buildPurchasesTab(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsListProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('هەڵە لە بارکردنی کاڵاکان: $err', style: AppTextStyles.bodyMedium),
      ),
      data: (allProducts) {
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
        final paidAmount = double.tryParse(_poPaidAmountController.text.trim()) ?? totalAmount;
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
                            const Spacer(),
                            if (_checkedProductIds.isNotEmpty)
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

            // Section 2: Top Control Bar (Supplier selection + Add Supplier + Warehouse + Notes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                                              '${s.name}${s.currentBalance > 0 ? " (قەرز: ${Formatters.currency(s.currentBalance)})" : ""}',
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
                                  (warehouses.any((w) => w.isMain)
                                      ? warehouses.firstWhere((w) => w.isMain).id
                                      : (warehouses.isNotEmpty ? warehouses.first.id : 1)),
                              isExpanded: true,
                              items: warehouses.map((w) {
                                return DropdownMenuItem<int>(
                                  value: w.id,
                                  child: Text(w.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedWarehouseId = val;
                                  });
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
              color: theme.colorScheme.surfaceContainerLow,
              child: RawAutocomplete<ProductModel>(
                textEditingController: _productSearchController,
                focusNode: _productSearchFocusNode,
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
                  return AppTextField(
                    controller: controller,
                    focusNode: focusNode,
                    hintText: 'گەڕان بەپێی ناوی کاڵا یان بارکۆد...',
                    prefixIcon: Icons.search,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prod = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(prod.name, style: AppTextStyles.bodyBold),
                              subtitle: Text(
                                'تێچوو: ${Formatters.currency(prod.costPrice)} • ستۆک: ${prod.totalStock} ${prod.unit ?? "دانە"}',
                                style: AppTextStyles.caption,
                              ),
                              trailing: const Icon(Icons.add_shopping_cart, size: 20),
                              onTap: () {
                                _addProductToCart(prod);
                                focusNode.unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Section 4: Cart Items List
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
                          onLongPress: () => _showItemConfigDialog(item),
                          borderRadius: BorderRadius.circular(10),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                // Thumbnail / Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: AppSpacing.sm),

                                // Product info & Unit details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      // Unit display & carton conversion info
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _showItemConfigDialog(item),
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
                                              child: Text(
                                                isCarton
                                                    ? 'کارتۆن (${item.quantity} کارتۆن = ${item.totalStockUnits} ${item.baseUnitName})'
                                                    : 'یەکە: ${item.baseUnitName}',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isCarton ? AppColors.purple : null,
                                                  fontSize: 11,
                                                ),
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
                                      const SizedBox(height: 2),
                                      Text(
                                        'کۆی گشتی دێڕ: ${Formatters.currency(item.totalLineCost)} د.ع',
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stepper: [-] [qty] [+]
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                                      onPressed: () => _removeFromCart(item),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 22),
                                      onPressed: () {
                                        setState(() {
                                          item.quantity += 1;
                                          _updatePaidAmountToTotal();
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                // Delete item
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                  onPressed: () => _deleteCartItem(item),
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

                        // Paid Amount field + quick buttons
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('بڕی پارەی دراو:', style: AppTextStyles.caption),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        _poPaidAmountController.text = totalAmount.toInt().toString();
                                        setState(() {});
                                      },
                                      child: Text(
                                        'نەقد',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        _poPaidAmountController.text = '0';
                                        setState(() {});
                                      },
                                      child: Text(
                                        'قەرز',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: _poPaidAmountController,
                                  keyboardType: TextInputType.number,
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0',
                                  ),
                                  onChanged: (_) => setState(() {}),
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
                                  : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('قەرزی ماوە:', style: AppTextStyles.caption),
                                Text(
                                  remainingDebt > 0 ? Formatters.currency(remainingDebt) : 'نەقد',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: remainingDebt > 0 ? AppColors.warning : AppColors.success,
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
                onTap: isConfirmed ? () => _receivePO(order) : null,
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
                      if (isDraft)
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                          tooltip: 'پەسەندکردن',
                          onPressed: () => _confirmPO(order),
                        ),
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
