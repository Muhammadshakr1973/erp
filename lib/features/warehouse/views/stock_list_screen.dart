import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/warehouse_stock_model.dart';
import '../providers/warehouse_provider.dart';

class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _filterLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAdjustStockDialog(WarehouseStockModel stock) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    String adjustType = 'ADJUSTMENT';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'دەستکاریکردنی ستۆک: ${stock.productName}',
                style: AppTextStyles.bodyBold,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'کۆگای دیاریکراو: ${stock.warehouseName}',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: adjustType,
                      decoration: const InputDecoration(
                        labelText: 'جۆری جوڵە',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ADJUSTMENT',
                          child: Text('جیاوازی کۆگا (ADJUSTMENT)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            adjustType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: amountController,
                      labelText: 'بڕی گۆڕانکاری (بۆ نمونە: ١٠ یان -٥)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: notesController,
                      labelText: 'تێبینییەکان',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('پاشگەزبوونەوە'),
                ),
                isSubmitting
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: () async {
                          final change = int.tryParse(amountController.text);
                          if (change == null || change == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تکایە بڕێکی دروست بنووسە'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await ref
                                .read(warehouseActionsProvider)
                                .adjustStock(
                                  warehouseId: stock.warehouseId,
                                  productId: stock.productId,
                                  quantityChange: change,
                                  type: adjustType,
                                  notes: notesController.text,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ستۆک بە سەرکەوتوویی نوێکرایەوە',
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
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                        child: const Text('پاشکەوتکردن'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReconcileDialog(WarehouseStockModel stock) {
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('هاوتاکردنەوەی ستۆک (Reconcile)'),
              content: Text(
                'ئایا دڵنیایت لە پشکنینی هاوتاکردنەوەی بڕی حجزکراو و گشتی بۆ کاڵای "${stock.productName}"؟ ئەم کارە تەنها بۆ پشکنین و دۆزینەوەی جیاوازییەکانە و هیچ گۆڕانکارییەک لە ستۆکی سێرڤەردا ناکات.',
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('نەخێر'),
                ),
                isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final result = await ref
                                .read(warehouseActionsProvider)
                                .reconcileStock(
                                  warehouseId: stock.warehouseId,
                                  productId: stock.productId,
                                );
                            if (context.mounted) {
                              Navigator.pop(context); // Close confirm dialog
                              _showReconciliationResult(stock, result);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                        child: const Text('بەڵێ، جێبەجێ بکە'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReconciliationResult(
      WarehouseStockModel stock, StockReconciliationModel result) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                result.isConsistent ? Icons.check_circle : Icons.warning_amber,
                color: result.isConsistent
                    ? AppColors.success
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('ئەنجامی هاوتاکردنەوە'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.productName,
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildReconcileRow(
                  'بڕی فیزیکی (تۆمارکراو)',
                  result.storedQuantity.toString(),
                ),
                _buildReconcileRow(
                  'بڕی فیزیکی (ژمێردراو)',
                  result.recalculatedQuantity.toString(),
                  isDiscrepant:
                      result.storedQuantity != result.recalculatedQuantity,
                ),
                const Divider(),
                _buildReconcileRow(
                  'بڕی حجزکراو (تۆمارکراو)',
                  result.storedReserved.toString(),
                ),
                _buildReconcileRow(
                  'بڕی حجزکراو (ژمێردراو)',
                  result.recalculatedReserved.toString(),
                  isDiscrepant:
                      result.storedReserved != result.recalculatedReserved,
                ),
                if (result.discrepancies.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text('جیاوازییە دۆزراوەکان:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...result.discrepancies.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $d',
                            style: AppTextStyles.caption.copyWith(
                              color: theme.colorScheme.error,
                            )),
                      )),
                ],
                const SizedBox(height: AppSpacing.md),
                if (result.isConsistent)
                  const Text(
                    'ئەم کاڵایە هیچ کێشەیەکی نییە و هاوتایە.',
                    style: TextStyle(color: AppColors.success),
                  )
                else
                  Text(
                    'جیاوازی دۆزرایەوە! تکایە تێبینی بکە کە ئەم پڕۆسەیە تەنها بۆ ڕاپۆرتکردن و دۆزینەوەی جیاوازییەکانە، و هیچ گۆڕانکارییەکی خۆکار لە ستۆکی سێرڤەردا ئەنجام نەدراوە.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('داخستن'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReconcileRow(String label, String value,
      {bool isDiscrepant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(
            value,
            style: AppTextStyles.bodyBold.copyWith(
              color: isDiscrepant ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stocksAsync = ref.watch(warehouseStocksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لیستی ستۆک', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            tooltip: 'سکانی باڕکۆد',
            onPressed: () {
              CameraBarcodeScanner.show(context, (barcode) {
                setState(() {
                  _searchQuery = barcode;
                  _searchController.text = barcode;
                });
              });
            },
          ),
          IconButton(
            icon: Icon(
              _filterLowStock ? Icons.filter_list_alt : Icons.filter_list,
              color: _filterLowStock ? theme.colorScheme.primary : null,
            ),
            tooltip: 'فلتەری ستۆکی کەم',
            onPressed: () {
              setState(() {
                _filterLowStock = !_filterLowStock;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(warehouseStocksProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(warehouseStocksProvider);
          await ref.read(warehouseStocksProvider.future);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: AppTextField(
                hintText: 'گەڕان بۆ کاڵا لە کۆگا (بە ناو یان باڕکۆد)...',
                prefixIcon: AppIcons.search,
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            Expanded(
              child: stocksAsync.when(
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
                        const Text('کێشەیەک ڕوویدا لە بارکردنی ستۆکەکان'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          err.toString().replaceAll('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.invalidate(warehouseStocksProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('دووبارە هەوڵبدەرەوە'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (stocks) {
                  var filtered = stocks.where((stock) {
                    final searchLower = _searchQuery.toLowerCase();
                    final matchesSearch =
                        stock.productName.toLowerCase().contains(searchLower) ||
                        stock.barcode.toLowerCase().contains(searchLower);
                    if (_filterLowStock) {
                      return matchesSearch && stock.quantity <= stock.minStockLevel;
                    }
                    return matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'هیچ کاڵایەک نەدۆزرایەوە بۆ گەڕانەکەت'
                                  : 'هیچ ستۆکێک لە کۆگادا تۆمار نەکراوە',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final stock = filtered[index];
                      final bool isLow = stock.quantity <= stock.minStockLevel;

                      return AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stock.productName,
                                    style: AppTextStyles.bodyBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stock.warehouseName} • حجزکراو: ${stock.reservedQuantity} • بەردەست: ${stock.availableQuantity}',
                                    style: AppTextStyles.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(
                                  label: 'ستۆک: ${stock.quantity}',
                                  type: isLow
                                      ? StatusBadgeType.danger
                                      : StatusBadgeType.info,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PermissionGuard(
                                      permission: 'stock.pack',
                                      fallback: const SizedBox.shrink(),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        tooltip: 'دەستکاریکردنی ستۆک',
                                        onPressed: () =>
                                            _showAdjustStockDialog(stock),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.sync_outlined,
                                        size: 20,
                                      ),
                                      tooltip: 'هاوتاکردنەوە',
                                      onPressed: () =>
                                          _showReconcileDialog(stock),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
