import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_dialog.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_breakpoints.dart';
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
  late int _selectedFromWarehouseId;
  int? _selectedToWarehouseId;
  late final TextEditingController _notesController;
  final Map<int, int> _items = {}; // productId -> quantity
  bool _isSubmitting = false;

  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(wp.vanTransferDraftStateProvider);
    _selectedFromWarehouseId = draft.fromWarehouseId ?? widget.fromWarehouseId;
    _selectedToWarehouseId = draft.toWarehouseId;
    _notesController = TextEditingController(text: draft.notes);
    _items.addAll(draft.items);

    _notesController.addListener(_syncDraft);
  }

  void _syncDraft() {
    ref.read(wp.vanTransferDraftStateProvider.notifier).state =
        wp.VanTransferDraft(
      fromWarehouseId: _selectedFromWarehouseId,
      toWarehouseId: _selectedToWarehouseId,
      notes: _notesController.text,
      items: Map<int, int>.from(_items),
    );
  }

  void _updateItems(void Function() updates) {
    setState(() {
      updates();
    });
    _syncDraft();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _productSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showAddProductDialog(List<ProductModel> allProducts) {
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.shortestSide < AppBreakpoints.tabletMin;
    final categoryNames = <int, String>{};
    for (final product in allProducts) {
      final categoryId = product.categoryId;
      if (categoryId == null) continue;
      final category = product.category;
      final name = category is Map ? category['name']?.toString() : null;
      categoryNames[categoryId] =
          name == null || name.isEmpty ? 'جۆر $categoryId' : name;
    }
    final categories = categoryNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : 640,
        maxHeight: screenSize.height,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isMobile ? 0 : 20),
        ),
      ),
      isDismissible: false,
      builder: (ctx) {
        String search = '';
        var selectedCategoryId = 0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final filtered = allProducts.where((p) {
              if (selectedCategoryId != 0 &&
                  p.categoryId != selectedCategoryId) {
                return false;
              }
              if (search.isEmpty) return true;
              final q = search.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.barcode.toLowerCase().contains(q) ||
                  (p.sku?.toLowerCase().contains(q) ?? false);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: isMobile ? 1 : 0.75,
              minChildSize: isMobile ? 1 : 0.5,
              maxChildSize: 1,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'دیاریکردنی کاڵا بۆ بارکردن',
                              style: AppTextStyles.h3,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'سکان بە کامێرا',
                            onPressed: () {
                              CameraBarcodeScanner.show(
                                context,
                                (barcode) {
                                  search = barcode.trim();
                                  setModalState(() {});
                                  return true;
                                },
                                closeOnScan: true,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'داخستن',
                            onPressed: () => Navigator.pop(ctx),
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
                      DropdownButtonFormField<int>(
                        value: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'فلتەر بەپێی جۆر',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('هەموو جۆرەکان'),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem(
                              value: category.key,
                              child: Text(category.value),
                            ),
                          ),
                        ],
                        onChanged: (categoryId) {
                          setModalState(() {
                            selectedCategoryId = categoryId ?? 0;
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
                                p.getStockForWarehouse(_selectedFromWarehouseId);

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
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: availableInSource <= 0
                                          ? null
                                          : () async {
                                              await _promptForQuantity(
                                                p,
                                                availableInSource,
                                                onQuantityChanged: () {
                                                  setModalState(() {});
                                                },
                                              );
                                              setModalState(() {});
                                            },
                                      child: Container(
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
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    onPressed: availableInSource <= 0
                                        ? null
                                        : () async {
                                            await _promptForQuantity(
                                              p,
                                              availableInSource,
                                              onQuantityChanged: () {
                                                setModalState(() {});
                                              },
                                            );
                                            setModalState(() {});
                                          },
                                    child: Text(currentQtyInCart > 0 ? 'گۆڕین' : 'دانان'),
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
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _promptForQuantity(
    ProductModel product,
    int available, {
    VoidCallback? onQuantityChanged,
  }) async {
    final isAlreadyInCart = _items.containsKey(product.id);
    int currentQty = _items[product.id] ?? 1;
    Timer? repeatTimer;

    void stopTimer() {
      repeatTimer?.cancel();
      repeatTimer = null;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDecrement = isAlreadyInCart ? currentQty > 0 : currentQty > 1;
            final canIncrement = currentQty < available;

            void incrementBy(int amount) {
              if (currentQty >= available) return;
              setDialogState(() {
                currentQty = (currentQty + amount).clamp(1, available);
              });
              if (currentQty >= available) {
                stopTimer();
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'داخستن',
                    onPressed: () {
                      stopTimer();
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('بڕی ${product.name}', style: AppTextStyles.bodyBold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بڕی بەردەست لە کۆگای نێرەر: $available دانە',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceContainerDark
                          : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Plus button (زیادکردن) - tap: +1, long press: +5 every 500ms
                        GestureDetector(
                          onTapDown: (_) => stopTimer(),
                          onTapUp: (_) => stopTimer(),
                          onTapCancel: stopTimer,
                          onLongPressStart: canIncrement
                              ? (_) {
                                  stopTimer();
                                  incrementBy(5);
                                  repeatTimer = Timer.periodic(
                                    const Duration(milliseconds: 500),
                                    (_) => incrementBy(5),
                                  );
                                }
                              : null,
                          onLongPressEnd: (_) => stopTimer(),
                          child: Material(
                            color: canIncrement
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: canIncrement
                                  ? () {
                                      stopTimer();
                                      incrementBy(1);
                                    }
                                  : null,
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: canIncrement
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 22,
                                  color: canIncrement
                                      ? Theme.of(context).colorScheme.primary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Center: Read-only quantity display
                        Expanded(
                          child: Center(
                            child: Text(
                              '$currentQty',
                              style: AppTextStyles.h2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                        // Minus button (کەمکردنەوە)
                        Material(
                          color: canDecrement
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.surfaceContainerHighestDark
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: canDecrement
                                ? () {
                                    stopTimer();
                                    setDialogState(() {
                                      currentQty--;
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: canDecrement
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Icon(
                                Icons.remove,
                                size: 22,
                                color: canDecrement
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight)
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQty == 0 ? AppColors.danger : null,
                  ),
                  onPressed: () {
                    stopTimer();
                    if (currentQty < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تکایە ژمارەیەکی دروست بنووسە')),
                      );
                      return;
                    }
                    if (currentQty > available) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'بڕی داواکراو ($currentQty) لە بەردەستی کۆگا ($available) زیاترە!',
                          ),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    _updateItems(() {
                      if (currentQty <= 0) {
                        _items.remove(product.id);
                      } else {
                        _items[product.id] = currentQty;
                      }
                    });
                    onQuantityChanged?.call();
                    Navigator.pop(ctx);
                  },
                  child: Text(currentQty == 0 ? 'سڕینەوە لە لیست' : 'جێگیرکردن'),
                ),
              ],
            );
          },
        );
      },
    );
    stopTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final productsAsync = ref.watch(productsListProvider);

    final allProducts = productsAsync.asData?.value ?? [];
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = AppBreakpoints.isMobile(screenSize.width);

    return Dialog(
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: theme.colorScheme.surface,
      child: SizedBox(
        width: isMobile ? double.infinity : 520,
        height: isMobile ? double.infinity : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isMobile ? double.infinity : screenSize.height * 0.9,
          ),
          child: Column(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'داخستن',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
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
                        'گواستنەوە',
                        style: AppTextStyles.bodyBold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Body
              Flexible(
                fit: isMobile ? FlexFit.tight : FlexFit.loose,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 16,
                  ),
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
                child: warehousesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => const Text('هەڵە لە بارکردنی کۆگاکان'),
                  data: (rawWarehouses) {
                    final Map<int, WarehouseModel> uniqueMap = {};
                    for (final w in rawWarehouses) {
                      if (w.isActive) {
                        uniqueMap[w.id] = w;
                      }
                    }

                    // Sender: Reserve or Physical (never Van)
                    final fromWarehouses =
                        uniqueMap.values.where((w) => !w.isVan).toList();

                    final effectiveFromId = fromWarehouses
                            .any((w) => w.id == _selectedFromWarehouseId)
                        ? _selectedFromWarehouseId
                        : (fromWarehouses.isNotEmpty
                            ? fromWarehouses.first.id
                            : null);

                    // Receiver: Physical or Cash Van (never Reserve) and not sender
                    final targets = effectiveFromId != null
                        ? uniqueMap.values
                            .where((w) =>
                                w.id != effectiveFromId && !w.isReserve)
                            .toList()
                        : <WarehouseModel>[];

                    int? effectiveToId = _selectedToWarehouseId;
                    if (effectiveToId == null ||
                        !targets.any((w) => w.id == effectiveToId)) {
                      if (targets.isNotEmpty) {
                        final firstVan =
                            targets.where((w) => w.isVan).firstOrNull;
                        effectiveToId = firstVan?.id ?? targets.first.id;
                      } else {
                        effectiveToId = null;
                      }
                    }
                    _selectedToWarehouseId = effectiveToId;

                    return Column(
                      children: [
                        // Source Warehouse Dropdown
                        DropdownButtonFormField<int>(
                          value: effectiveFromId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'کۆگای نێرەر (لە کۆگاوە) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.arrow_upward,
                                color: AppColors.danger, size: 18),
                          ),
                          items: fromWarehouses.map((w) {
                            return DropdownMenuItem<int>(
                              value: w.id,
                              child: Row(
                                children: [
                                  Icon(
                                    w.isReserve
                                        ? Icons.inventory_2_outlined
                                        : Icons.warehouse_outlined,
                                    size: 16,
                                    color: w.isReserve
                                        ? Colors.purple
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${w.name} (${w.isReserve ? "یەدەگ" : "فیزیکی"})',
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
                                _selectedFromWarehouseId = val;
                                final newTargets = uniqueMap.values
                                    .where((w) =>
                                        w.id != val && !w.isReserve)
                                    .toList();
                                if (!newTargets.any(
                                    (w) => w.id == _selectedToWarehouseId)) {
                                  final van = newTargets
                                      .where((w) => w.isVan)
                                      .firstOrNull;
                                  _selectedToWarehouseId = van?.id ??
                                      (newTargets.isNotEmpty
                                          ? newTargets.first.id
                                          : null);
                                }
                              });
                              _syncDraft();
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Destination Warehouse Dropdown
                        if (targets.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'هیچ کۆگایەکی تر بەردەست نییە بۆ گواستنەوە',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            value: effectiveToId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'کۆگای وەرگر (بۆ کۆگای) *',
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
                                        '${w.name} (${w.isVan ? "کاشڤان" : "فیزیکی"})',
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
                                  final targetW = uniqueMap[val];
                                  if (targetW != null) {
                                    if (targetW.isVan) {
                                      _notesController.text =
                                          'بارکردنی کاڵا بۆ ئۆتۆمبێلی کاشڤان (${targetW.name})';
                                    } else {
                                      _notesController.text =
                                          'گواستنەوەی کاڵا بۆ ${targetW.name}';
                                    }
                                  }
                                });
                                _syncDraft();
                              }
                            },
                          ),
                      ],
                    );
                  },
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
                          _selectedFromWarehouseId) ??
                      0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onLongPress: () async {
                          final confirm = await AppDialog.showConfirm(
                            context,
                            title: 'سڕینەوەی کاڵا',
                            message: 'ئایا دڵنیایت لە سڕینەوەی کاڵای "$name" لەم لیستە؟',
                            confirmText: 'بەڵێ، بسڕەوە',
                            isDanger: true,
                          );
                          if (confirm == true && mounted) {
                            _updateItems(() {
                              _items.remove(entry.key);
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
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
                            ],
                          ),
                        ),
                      ),
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

              // Footer
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  12,
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                ),
                child: _isSubmitting
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('بارکردن و دەرکردنی پسوڵە'),
                          onPressed: () async {
                            if (_selectedToWarehouseId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تکایە کۆگای وەرگر دیاری بکە')),
                              );
                              return;
                            }
                            if (_items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('تکایە لانی کەم یەک کاڵا دیاری بکە')),
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
                                    fromWarehouseId: _selectedFromWarehouseId,
                                    toWarehouseId: _selectedToWarehouseId!,
                                    items: itemsPayload,
                                    notes: _notesController.text.trim(),
                                    completeNow: true, // Auto-completes the van load!
                                  );

                              // Clear draft upon successful transfer
                              ref.read(wp.vanTransferDraftStateProvider.notifier).state =
                                  const wp.VanTransferDraft();

                              if (context.mounted) {
                                Navigator.pop(context, result);
                                final allW =
                                    ref.read(warehouseListProvider).value ?? [];
                                final targetW = allW
                                    .where((w) => w.id == _selectedToWarehouseId)
                                    .firstOrNull;
                                final isVan = targetW?.isVan ?? true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isVan
                                          ? 'کاڵاکان بە سەرکەوتوویی بارکران بۆ ئۆتۆمبێلی کاشڤان'
                                          : 'کاڵاکان بە سەرکەوتوویی گوازرانەوە بۆ ${targetW?.name ?? "کۆگای وەرگر"}',
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
