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
    }
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
    _searchFocusNode.dispose();
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

    if (_cart.isEmpty) {
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
      itemsList.add({'product_id': productId, 'quantity': qty});
    });

    final String sharedKey = widget.existingOrder?.sharedKey ??
        'order_${DateTime.now().microsecondsSinceEpoch}';
    final int version = widget.existingOrder?.version ?? 1;

    final payload = {
      'customer_id': _selectedCustomer!.id,
      'warehouse_id': warehouseId,
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
                          Expanded(
                            child: _buildProductSelectionSection(
                              productsAsync,
                              allProducts,
                            ),
                          ),
                          _buildMobileCartBar(allProducts, warehousesAsync),
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
                                  '${Formatters.currency(unitPrice)} / ${product?.unit ?? "دانە"}',
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

  Widget _buildMobileCartBar(
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
                    Formatters.currency(totalAmount),
                    style: AppTextStyles.price,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: AppButton(
                width: 160,
                text: 'بینین و تەواوکردن',
                onPressed: (_cart.isNotEmpty && !warehousesAsync.hasError)
                    ? () {
                        _showMobileCartBottomSheet(allProducts, warehousesAsync);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileCartBottomSheet(
    List<ProductModel> allProducts,
    AsyncValue<List<WarehouseModel>> warehousesAsync,
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
              child: SingleChildScrollView(
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
                        separatorBuilder: (context, index) => const Divider(height: 1),
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
                              '$qty ${product?.unit ?? "دانە"} x ${Formatters.currency(unitPrice)} = ${Formatters.currency(qty * unitPrice)}',
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
                          Formatters.currency(totalAmount),
                          style: AppTextStyles.priceLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      width: double.infinity,
                      text: 'پشتڕاستکردنەوە و ناردن',
                      isLoading: _isSubmitting,
                      onPressed: (!warehousesAsync.hasError && _cart.isNotEmpty)
                          ? () {
                              Navigator.pop(context);
                              _submitOrder(allProducts, warehousesAsync);
                            }
                          : null,
                      size: AppButtonSize.lg,
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
}
