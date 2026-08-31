import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
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
import '../../orders/providers/orders_provider.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  final int? preselectedCustomerId;

  const CreateOrderScreen({super.key, this.preselectedCustomerId});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  Customer? _selectedCustomer;
  int? _selectedWarehouseId;
  final Map<int, int> _cart = {}; // product_id -> quantity
  String _discountType = 'PERCENT';
  double _discountValue = 0.0;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preselectedCustomerId != null) {
        _loadPreselectedCustomer();
      }
    });
  }

  void _loadPreselectedCustomer() async {
    final customers = await ref.read(customerListProvider.future);
    final match = customers
        .where((c) => c.id == widget.preselectedCustomerId)
        .firstOrNull;
    if (match != null) {
      setState(() {
        _selectedCustomer = match;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _getProductUnitPrice(ProductModel product) {
    if (_selectedCustomer == null) {
      return product.priceN2 > 0 ? product.priceN2 : product.costPrice;
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
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]! > 1) {
          _cart[productId] = _cart[productId]! - 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  void _scanBarcode(List<ProductModel> products) {
    CameraBarcodeScanner.show(context, (scannedBarcode) {
      final matched = products
          .where((p) => p.barcode == scannedBarcode || p.sku == scannedBarcode)
          .firstOrNull;
      if (matched != null) {
        _addToCart(matched.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${matched.name} بەکارهێنرا بۆ سەبەتە'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هیچ کاڵایەک نەدۆزرایەوە بە کۆدی: $scannedBarcode'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _submitOrder(
    List<ProductModel> products,
    List<WarehouseModel> warehouses,
  ) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تکایە سەرەتا کڕیارێک هەڵبژێرە'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سەبەتە بەتاڵە! کاڵا بنێرە ناو سەبەتە'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final warehouseId =
        _selectedWarehouseId ??
        (warehouses.isNotEmpty ? warehouses.first.id : 1);

    final List<Map<String, dynamic>> itemsList = [];
    _cart.forEach((productId, qty) {
      itemsList.add({'product_id': productId, 'quantity': qty});
    });

    final String sharedKey = 'order_${DateTime.now().microsecondsSinceEpoch}';

    final payload = {
      'customer_id': _selectedCustomer!.id,
      'warehouse_id': warehouseId,
      'discount_type': _discountType,
      'discount_percent': _discountType == 'PERCENT' ? _discountValue : null,
      'discount_amount': _discountType == 'FIXED' ? _discountValue : null,
      'shared_key': sharedKey,
      'version': 1,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'items': itemsList,
    };

    setState(() => _isSubmitting = true);

    try {
      await ref.read(orderActionsProvider).createOrder(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پسوڵەکە بە سەرکەوتوویی دروستکرا'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە لە تۆمارکردنی پسوڵە: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'orders.create',
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final customersAsync = ref.watch(customerListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    final allProducts = productsAsync.asData?.value ?? [];
    final allWarehouses = warehousesAsync.asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('پسوڵەی نوێ', style: AppTextStyles.h2),
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
              _buildTopBar(customersAsync, allWarehouses),

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
                            child: _buildCartPanel(allProducts, allWarehouses),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _buildProductSelectionSection(
                              productsAsync,
                              allProducts,
                            ),
                          ),
                          _buildMobileCartBar(allProducts, allWarehouses),
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
    List<WarehouseModel> warehouses,
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
                  error: (_, __) => const Text('هەڵە لە بارکردنی کڕیاران'),
                  data: (customers) {
                    return DropdownButtonFormField<int>(
                      value: _selectedCustomer?.id,
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
                        setState(() {
                          _selectedCustomer = customers
                              .where((c) => c.id == val)
                              .firstOrNull;
                        });
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
        ],
      ),
    );
  }

  Widget _buildProductSelectionSection(
    AsyncValue<List<ProductModel>> productsAsync,
    List<ProductModel> allProducts,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _searchController,
            hintText: 'گەڕان بەپێی ناوی کاڵا یان باڕکۆد...',
            prefixIcon: AppIcons.search,
            onChanged: (query) {
              ref.read(productSearchProvider.notifier).search(query);
            },
          ),
        ),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('هەڵە: $err')),
            data: (products) {
              if (products.isEmpty) {
                return const Center(child: Text('هیچ کاڵایەک نەدۆزرایەوە'));
              }
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.72,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final qtyInCart = _cart[product.id] ?? 0;
                  final unitPrice = _getProductUnitPrice(product);

                  return _buildProductCard(product, unitPrice, qtyInCart);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    ProductModel product,
    double unitPrice,
    int qtyInCart,
  ) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => _addToCart(product.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
                if (qtyInCart > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '$qtyInCart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.name,
            style: AppTextStyles.bodyBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text('${Formatters.currency(unitPrice)}', style: AppTextStyles.price),
        ],
      ),
    );
  }

  Widget _buildCartPanel(
    List<ProductModel> allProducts,
    List<WarehouseModel> warehouses,
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

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product?.name ?? 'کاڵا',
                                  style: AppTextStyles.bodyBold,
                                ),
                                Text(
                                  '${Formatters.currency(unitPrice)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _removeFromCart(productId),
                              ),
                              Text('$qty', style: AppTextStyles.bodyBold),
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
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _notesController,
                  hintText: 'تێبینی (ئارەزوومەندانە)...',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆ کۆتایی:', style: AppTextStyles.bodyLarge),
                    Text(
                      '${Formatters.currency(totalAmount)}',
                      style: AppTextStyles.priceLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  text: 'تەواوکردنی پسوڵە',
                  isLoading: _isSubmitting,
                  onPressed: _cart.isNotEmpty
                      ? () => _submitOrder(allProducts, warehouses)
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

  Widget _buildMobileCartBar(
    List<ProductModel> allProducts,
    List<WarehouseModel> warehouses,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$cartItemCount کاڵا لە سەبەتەدا',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    '${Formatters.currency(totalAmount)}',
                    style: AppTextStyles.price,
                  ),
                ],
              ),
            ),
            AppButton(
              text: 'بینین و تەواوکردن',
              onPressed: _cart.isNotEmpty
                  ? () {
                      _showMobileCartBottomSheet(allProducts, warehouses);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileCartBottomSheet(
    List<ProductModel> allProducts,
    List<WarehouseModel> warehouses,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final subtotal = _calculateSubtotal(allProducts);
            final permDiscountPercent =
                _selectedCustomer?.permanentDiscount ?? 0.0;
            final permDiscountAmount = (subtotal * permDiscountPercent) / 100;
            final amountAfterPerm = subtotal - permDiscountAmount;
            final invoiceDiscountAmount = _discountType == 'PERCENT' 
        ? (amountAfterPerm * _discountValue) / 100 
        : _discountValue;
            final totalAmount = amountAfterPerm - invoiceDiscountAmount;

            return Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تەواوکردنی پسوڵە', style: AppTextStyles.h2),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final productId = _cart.keys.elementAt(index);
                        final qty = _cart[productId]!;
                        final product = allProducts
                            .where((p) => p.id == productId)
                            .firstOrNull;
                        final unitPrice = product != null
                            ? _getProductUnitPrice(product)
                            : 0.0;

                        return ListTile(
                          title: Text(product?.name ?? 'کاڵا'),
                          subtitle: Text(
                            '$qty x ${Formatters.currency(unitPrice)} = ${Formatters.currency(qty * unitPrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () {
                                  _removeFromCart(productId);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                              Text('$qty'),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  _addToCart(productId);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                            setModalState(() {
                              _discountType = val;
                              if (_discountType == 'PERCENT' && _discountValue > 100) {
                                _discountValue = 100;
                              }
                            });
                            setState(() {});
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
                            setModalState(() {
                              _discountValue = parsed;
                              if (_discountType == 'PERCENT' && _discountValue > 100) {
                                _discountValue = 100;
                              }
                            });
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _notesController,
                    hintText: 'تێبینی (ئارەزوومەندانە)...',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('کۆی گشتی:', style: AppTextStyles.bodyLarge),
                      Text(
                        '${Formatters.currency(totalAmount)}',
                        style: AppTextStyles.priceLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    text: 'پشتڕاستکردنەوە و ناردن',
                    isLoading: _isSubmitting,
                    onPressed: () {
                      Navigator.pop(context);
                      _submitOrder(allProducts, warehouses);
                    },
                    size: AppButtonSize.lg,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
