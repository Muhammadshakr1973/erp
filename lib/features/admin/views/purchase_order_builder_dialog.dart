import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/models/product_model.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/products_provider.dart';
import '../../products/providers/suppliers_provider.dart';
import '../../products/views/product_form_dialog.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../models/purchase_requirement_model.dart';
import '../providers/purchase_provider.dart';

class PurchaseOrderBuilderDialog extends ConsumerStatefulWidget {
  final List<PurchaseRequirementModel> requirements;

  const PurchaseOrderBuilderDialog({
    super.key,
    required this.requirements,
  });

  @override
  ConsumerState<PurchaseOrderBuilderDialog> createState() =>
      _PurchaseOrderBuilderDialogState();
}

class _PurchaseOrderBuilderDialogState
    extends ConsumerState<PurchaseOrderBuilderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();
  final List<_RequirementLine> _requirementLines = [];
  final List<_AdditionalLine> _additionalLines = [];
  final List<_AdditionalLine> _removedAdditionalLines = [];
  ProductModel? _productToAdd;
  int? _newWarehouseId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _requirementLines.addAll(
      widget.requirements.map(_RequirementLine.new),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _productSearchController.dispose();
    for (final line in _requirementLines) {
      line.dispose();
    }
    for (final line in _additionalLines) {
      line.dispose();
    }
    for (final line in _removedAdditionalLines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    if (_requirementLines.isEmpty && _additionalLines.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'لانیکەم یەک کاڵا زیاد بکە',
        type: SnackbarType.warning,
      );
      return;
    }

    final requirementItems = _requirementLines.map((line) {
      return {
        'id': line.requirement.id,
        'quantity': int.parse(line.quantityController.text),
        'supplier_id': line.supplierId,
      };
    }).toList();
    final additionalItems = _additionalLines.map((line) {
      return {
        'product_id': line.product.id,
        'quantity': int.parse(line.quantityController.text),
        'supplier_id': line.supplierId,
        'warehouse_id': line.warehouseId,
      };
    }).toList();

    setState(() => _isSubmitting = true);
    try {
      await ref.read(purchaseActionsProvider).convertRequirementsToPO(
            requirementIds: const [],
            requirementItems: requirementItems,
            additionalItems: additionalItems,
            notes: _notesController.text,
          );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'پسوڵەکانی کڕین بەسەرکەوتوویی دروستکران',
        type: SnackbarType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: error.toString().replaceAll('Exception: ', ''),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addProduct(List<WarehouseModel> warehouses) {
    final product = _productToAdd;
    if (product == null) {
      AppSnackbar.show(
        context,
        message: 'سەرەتا کاڵایەک هەڵبژێرە',
        type: SnackbarType.warning,
      );
      return;
    }
    final warehouseId = _newWarehouseId ?? _defaultWarehouseId(warehouses);
    if (warehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'کۆگا بۆ کاڵای زیادە دیاری بکە',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() {
      _additionalLines.add(
        _AdditionalLine(
          product: product,
          supplierId: product.supplierId,
          warehouseId: warehouseId,
        ),
      );
      _productToAdd = null;
      _productSearchController.clear();
      _newWarehouseId = null;
    });
  }

  Future<void> _showAddNewProductDialog(List<WarehouseModel> warehouses) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ProductFormDialog(),
    );

    if (!mounted || result == null) return;

    ProductModel? createdProduct;
    if (result is ProductModel) {
      createdProduct = result;
    } else {
      final list = ref.read(productsListProvider).valueOrNull;
      if (list != null && list.isNotEmpty) {
        createdProduct = list.first;
      }
    }

    if (createdProduct != null && mounted) {
      setState(() {
        _productToAdd = createdProduct;
      });
      _addProduct(warehouses);
      AppSnackbar.show(
        context,
        message: '«${createdProduct.name}» زیادکرا بۆ پسوڵەی کڕین',
        type: SnackbarType.success,
      );
    }
  }

  int? _defaultWarehouseId(List<WarehouseModel> warehouses) {
    final userWarehouseId = ref.read(authProvider).user?.warehouseId;
    if (userWarehouseId != null &&
        warehouses.any((warehouse) => warehouse.id == userWarehouseId)) {
      return userWarehouseId;
    }
    if (_requirementLines.length == 1 &&
        warehouses.any(
          (warehouse) =>
              warehouse.id == _requirementLines.first.requirement.warehouseId,
        )) {
      return _requirementLines.first.requirement.warehouseId;
    }
    if (warehouses.length == 1) return warehouses.first.id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);
    final productsAsync = ref.watch(productsListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    return suppliersAsync.when(
      loading: _loadingDialog,
      error: (error, stack) => _errorDialog(error.toString()),
      data: (suppliers) => productsAsync.when(
        loading: _loadingDialog,
        error: (error, stack) => _errorDialog(error.toString()),
        data: (products) => warehousesAsync.when(
          loading: _loadingDialog,
          error: (error, stack) => _errorDialog(error.toString()),
          data: (warehouses) => _buildDialog(
            suppliers,
            products.where((product) => product.isActive).toList(),
            _availableWarehouses(warehouses),
          ),
        ),
      ),
    );
  }

  List<WarehouseModel> _availableWarehouses(List<WarehouseModel> warehouses) {
    final assignedWarehouseId = ref.read(authProvider).user?.warehouseId;
    return warehouses.where((warehouse) {
      return warehouse.isActive &&
          (assignedWarehouseId == null || warehouse.id == assignedWarehouseId);
    }).toList();
  }

  Widget _loadingDialog() => AlertDialog(
        title: _dialogTitle(
          'ئامادەکردنی داتاکان',
          () => Navigator.of(context).pop(false),
        ),
        content: const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
      );

  Widget _errorDialog(String error) => AlertDialog(
        title: _dialogTitle(
          'کێشە لە بارکردنی داتاکان',
          () => Navigator.of(context).pop(false),
        ),
        content: Text(error.replaceAll('Exception: ', '')),
        actions: [
          TextButton(
            onPressed: () {
              ref.invalidate(suppliersListProvider);
              ref.invalidate(productsListProvider);
              ref.invalidate(warehouseListProvider);
            },
            child: const Text('دووبارە هەوڵبدەرەوە'),
          ),
        ],
      );

  Widget _dialogTitle(String title, VoidCallback onClose) => SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'داخستن',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(title, textAlign: TextAlign.center),
            ),
          ],
        ),
      );

  Widget _buildDialog(
    List<SupplierModel> suppliers,
    List<ProductModel> products,
    List<WarehouseModel> warehouses,
  ) {
    final size = MediaQuery.of(context).size;
    final matchingProducts = _productSearchController.text.trim().isEmpty
        ? <ProductModel>[]
        : products
            .where((product) {
              final query = _productSearchController.text.trim().toLowerCase();
              return product.name.toLowerCase().contains(query) ||
                  (product.sku?.toLowerCase().contains(query) ?? false) ||
                  product.barcode.toLowerCase().contains(query);
            })
            .take(8)
            .toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      title: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'داخستن',
                icon: const Icon(Icons.close),
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'دروستکردنی پسوڵەی کڕین',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyBold,
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: size.width > 680 ? 600 : size.width * 0.9,
        height: size.height * 0.68,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_requirementLines.isNotEmpty) ...[
                Text('کاڵا پێویستەکان', style: AppTextStyles.bodyBold),
                const SizedBox(height: AppSpacing.sm),
                ..._requirementLines.map(
                  (line) => _requirementLine(line, suppliers),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text('زیادکردنی کاڵای تر', style: AppTextStyles.bodyBold),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _productSearchController,
                decoration: InputDecoration(
                  labelText: 'گەڕان بۆ کاڵا',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'زیادکردنی کاڵای نوێ',
                    onPressed: () => _showAddNewProductDialog(warehouses),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _productToAdd = null),
              ),
              if (matchingProducts.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: matchingProducts.length,
                      itemBuilder: (context, index) {
                        final product = matchingProducts[index];
                        return ListTile(
                          dense: true,
                          title: Text(product.name),
                          subtitle: Text(
                            'نرخی تێچوو: ${product.costPrice.toStringAsFixed(0)}',
                          ),
                          onTap: () => setState(() {
                            _productToAdd = product;
                            _productSearchController.text = product.name;
                          }),
                        );
                      },
                    ),
                  ),
                ),
              if (warehouses.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: _newWarehouseId ?? _defaultWarehouseId(warehouses),
                  decoration: const InputDecoration(labelText: 'کۆگا بۆ کاڵای زیادە'),
                  items: warehouses
                      .map(
                        (warehouse) => DropdownMenuItem<int>(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _newWarehouseId = value),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _addProduct(warehouses),
                  icon: const Icon(Icons.add),
                  label: const Text('زیادکردنی کاڵا'),
                ),
              ),
              ..._additionalLines.map(
                (line) => _additionalLine(line, suppliers, warehouses),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'تێبینی (ئارەزوومەندانە)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('دروستکردنی پسوڵە'),
        ),
      ],
    );
  }

  Widget _requirementLine(
    _RequirementLine line,
    List<SupplierModel> suppliers,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.requirement.productName, style: AppTextStyles.bodyBold),
            Text(
              'پێویست: ${line.requirement.requiredQuantity} • '
              'کۆگا: ${line.requirement.warehouseName}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'بڕی کڕین',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');
                      if (quantity == null ||
                          quantity < line.requirement.requiredQuantity) {
                        return 'لانیکەم ${line.requirement.requiredQuantity}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _supplierDropdown(line.supplierId, suppliers,
                    (value) => setState(() => line.supplierId = value))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _additionalLine(
    _AdditionalLine line,
    List<SupplierModel> suppliers,
    List<WarehouseModel> warehouses,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(line.product.name, style: AppTextStyles.bodyBold),
                ),
                IconButton(
                  tooltip: 'لابردن',
                  onPressed: () => setState(() {
                    _additionalLines.remove(line);
                    _removedAdditionalLines.add(line);
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              'نرخی تێچوو: ${line.product.costPrice.toStringAsFixed(0)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: line.quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'بڕی کڕین',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final quantity = int.tryParse(value ?? '');
                return quantity == null || quantity < 1
                    ? 'بڕ دەبێت لە ٠ گەورەتر بێت'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _supplierDropdown(
              line.supplierId,
              suppliers,
              (value) => setState(() => line.supplierId = value),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<int>(
              value: line.warehouseId,
              decoration: const InputDecoration(labelText: 'کۆگا'),
              validator: (value) => value == null ? 'کۆگا دیاری بکە' : null,
              items: warehouses
                  .map(
                    (warehouse) => DropdownMenuItem<int>(
                      value: warehouse.id,
                      child: Text(warehouse.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => line.warehouseId = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplierDropdown(
    int? supplierId,
    List<SupplierModel> suppliers,
    ValueChanged<int?> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      value: suppliers.any((supplier) => supplier.id == supplierId)
          ? supplierId
          : null,
      decoration: const InputDecoration(
        labelText: 'دابینکەر',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'دابینکەر دیاری بکە' : null,
      items: suppliers
          .map(
            (supplier) => DropdownMenuItem<int>(
              value: supplier.id,
              child: Text(
                supplier.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _RequirementLine {
  final PurchaseRequirementModel requirement;
  final TextEditingController quantityController;
  int? supplierId;

  _RequirementLine(this.requirement)
      : quantityController = TextEditingController(
          text: requirement.requiredQuantity.toString(),
        ),
        supplierId = requirement.supplierId;

  void dispose() => quantityController.dispose();
}

class _AdditionalLine {
  final ProductModel product;
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  int? supplierId;
  int? warehouseId;

  _AdditionalLine({
    required this.product,
    required this.supplierId,
    required this.warehouseId,
  });

  void dispose() => quantityController.dispose();
}
