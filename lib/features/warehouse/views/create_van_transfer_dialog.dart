import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../providers/warehouse_provider.dart' as wp;

class CreateVanTransferDialog extends ConsumerStatefulWidget {
  final int fromWarehouseId;
  final String fromWarehouseName;

  const CreateVanTransferDialog({
    super.key,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
  });

  @override
  ConsumerState<CreateVanTransferDialog> createState() =>
      _CreateVanTransferDialogState();
}

class _CreateVanTransferDialogState
    extends ConsumerState<CreateVanTransferDialog> {
  int? _selectedToWarehouseId;
  final TextEditingController _notesController =
      TextEditingController(text: 'بارکردنی کاڵا بۆ ئۆتۆمبێلی کاشڤان');
  final Map<int, int> _items = {}; // productId -> quantity
  bool _isSubmitting = false;

  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _notesController.dispose();
    _productSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showAddProductDialog(List<ProductModel> allProducts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final filtered = allProducts.where((p) {
              if (search.isEmpty) return true;
              final q = search.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.barcode.toLowerCase().contains(q) ||
                  (p.sku?.toLowerCase().contains(q) ?? false);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'دیاریکردنی کاڵا بۆ بارکردن',
                            style: AppTextStyles.h3,
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'سکان بە کامێرا',
                            onPressed: () {
                              CameraBarcodeScanner.show(
                                context,
                                (barcode) {
                                  if (barcode.isNotEmpty) {
                                    setModalState(() {
                                      search = barcode;
                                    });
                                  }
                                },
                                closeOnScan: true,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        hintText: 'گەڕان بەپێی ناوی کاڵا یان بارکۆد...',
                        prefixIcon: Icons.search,
                        onChanged: (val) {
                          setModalState(() {
                            search = val.trim();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final currentQtyInCart = _items[p.id] ?? 0;
                            final availableInSource =
                                p.getStockForWarehouse(widget.fromWarehouseId);

                            return ListTile(
                              title: Text(p.name,
                                  style: AppTextStyles.bodyBold),
                              subtitle: Text(
                                'باڕکۆد: ${p.barcode} • بەردەست لە کۆگای نێرەر: $availableInSource دانە',
                                style: AppTextStyles.caption.copyWith(
                                  color: availableInSource > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (currentQtyInCart > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$currentQtyInCart دانە',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    onPressed: availableInSource <= 0
                                        ? null
                                        : () {
                                            _promptForQuantity(p, availableInSource);
                                          },
                                    child: const Text('دانان'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _promptForQuantity(ProductModel product, int available) {
    final qtyController = TextEditingController(
      text: '${_items[product.id] ?? 1}',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('بڕی ${product.name}', style: AppTextStyles.bodyBold),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بڕی بەردەست لە کۆگای نێرەر: $available دانە',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: qtyController,
                labelText: 'بڕی بارکردن (دانە)',
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تکایە ژمارەیەکی دروست بنووسە')),
                  );
                  return;
                }
                if (qty > available) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'بڕی داواکراو ($qty) لە بەردەستی کۆگا ($available) زیاترە!',
                      ),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                setState(() {
                  _items[product.id] = qty;
                });
                Navigator.pop(ctx);
              },
              child: const Text('جێگیرکردن'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final productsAsync = ref.watch(productsListProvider);

    final allProducts = productsAsync.asData?.value ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'بارکردنی نوێ بۆ کاشڤان / گواستنەوە',
              style: AppTextStyles.bodyBold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Source & Target Warehouses
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'کۆگای نێرەر: ${widget.fromWarehouseName}',
                          style: AppTextStyles.bodyBold,
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    warehousesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => const Text('هەڵە لە بارکردنی کۆگاکان'),
                      data: (warehouses) {
                        final targets = warehouses
                            .where((w) => w.id != widget.fromWarehouseId)
                            .toList();

                        // Prefer Van warehouses if any
                        if (_selectedToWarehouseId == null &&
                            targets.isNotEmpty) {
                          final firstVan = targets.firstWhere(
                            (w) => w.isVan,
                            orElse: () => targets.first,
                          );
                          _selectedToWarehouseId = firstVan.id;
                        }

                        return DropdownButtonFormField<int>(
                          initialValue: _selectedToWarehouseId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'کۆگای وەرگر (ئۆتۆمبێلی کاشڤان) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.arrow_downward,
                                color: AppColors.success, size: 18),
                          ),
                          items: targets.map((w) {
                            return DropdownMenuItem<int>(
                              value: w.id,
                              child: Row(
                                children: [
                                  Icon(
                                    w.isVan
                                        ? Icons.local_shipping_outlined
                                        : Icons.warehouse_outlined,
                                    size: 16,
                                    color: w.isVan
                                        ? Colors.orange
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${w.name} ${w.isVan ? "(کاشڤان)" : ""}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedToWarehouseId = val;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Products List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'کاڵاکانی بارکراو (${_items.length} جۆر)',
                    style: AppTextStyles.bodyBold,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('زیادکردنی کاڵا'),
                    onPressed: () => _showAddProductDialog(allProducts),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 3. Items Table / Cards
              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'هیچ کاڵایەک دانەنراوە بۆ بارکردن.\nتکایە "زیادکردنی کاڵا" دابگرە.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
                )
              else
                ..._items.entries.map((entry) {
                  ProductModel? product;
                  for (final p in allProducts) {
                    if (p.id == entry.key) {
                      product = p;
                      break;
                    }
                  }
                  final name = product?.name ?? 'کاڵا #${entry.key}';
                  final available = product?.getStockForWarehouse(
                          widget.fromWarehouseId) ??
                      0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTextStyles.bodyBold),
                              Text('بەردەست لە نێرەر: $available دانە',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${entry.value} دانە',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.danger, size: 20),
                          tooltip: 'سڕینەوە',
                          onPressed: () {
                            setState(() {
                              _items.remove(entry.key);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notesController,
                labelText: 'تێبینی / ژمارەی گەشت',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('پاشگەزبوونەوە'),
        ),
        _isSubmitting
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('بارکردن و دەرکردنی پسوڵە'),
                onPressed: () async {
                  if (_selectedToWarehouseId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تکایە کۆگای وەرگر دیاری بکە')),
                    );
                    return;
                  }
                  if (_items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('تکایە لانی کەم یەک کاڵا دیاری بکە')),
                    );
                    return;
                  }

                  setState(() {
                    _isSubmitting = true;
                  });

                  try {
                    final itemsPayload = _items.entries.map((e) {
                      return {
                        'product_id': e.key,
                        'quantity': e.value,
                      };
                    }).toList();

                    final result = await ref
                        .read(wp.warehouseActionsProvider)
                        .createStockTransfer(
                          fromWarehouseId: widget.fromWarehouseId,
                          toWarehouseId: _selectedToWarehouseId!,
                          items: itemsPayload,
                          notes: _notesController.text.trim(),
                          completeNow: true, // Auto-completes the van load!
                        );

                    if (context.mounted) {
                      Navigator.pop(context, result);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'کاڵاکان بە سەرکەوتوویی بارکران بۆ ئۆتۆمبێلی کاشڤان',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  } finally {
                    if (context.mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  }
                },
              ),
      ],
    );
  }
}
