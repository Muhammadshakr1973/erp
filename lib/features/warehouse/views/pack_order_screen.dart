import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/warehouse_order_model.dart';
import '../providers/warehouse_provider.dart';

class PackOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PackOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<PackOrderScreen> createState() => _PackOrderScreenState();
}

class _PackOrderScreenState extends ConsumerState<PackOrderScreen> {
  final Set<int> _packingItemIds = {};
  bool _isSubmittingReady = false;

  Future<void> _togglePack(WarehouseOrderItemModel item, bool value) async {
    if (_packingItemIds.contains(item.id)) return;

    setState(() {
      _packingItemIds.add(item.id);
    });

    try {
      await ref.read(warehouseActionsProvider).packItem(item.id, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'کاڵاکە پاکەت کرا' : 'کاڵاکە لە پاکەتکردن لادرا'),
            backgroundColor: value ? AppColors.success : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('کێشە لە پاکەتکردن'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشە'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _packingItemIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _submitReady(WarehouseOrderModel order) async {
    if (_isSubmittingReady) return;

    // Check if some items are not packed and confirm partial ready
    final bool hasUnpacked = order.items.any((e) => !e.isPacked);
    if (hasUnpacked) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ئامادەکردنی بەشەکی (Partial Ready)'),
          content: const Text(
            'ئایا دڵنیایت لە ئامادەکردنی ئەم پسوڵەیە بەشێوەی بەشەکی؟ ئەو کاڵایانەی کە پاکەت نەکراون لە پسوڵەکە لادەبرێن و بڕی حجزکراویان ئازاد دەکرێت.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نەخێر'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بەڵێ، ئامادەیە'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isSubmittingReady = true;
    });

    try {
      await ref.read(warehouseActionsProvider).markOrderReady(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پسوڵەکە بە سەرکەوتوویی بە ئامادەکراو تۆمارکرا'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('شکست هێنا'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشە'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReady = false;
        });
      }
    }
  }

  void _onScanBarcode(WarehouseOrderModel order) {
    CameraBarcodeScanner.show(context, (scanned) {
      // Find item matching product SKU/id or name
      WarehouseOrderItemModel? item;
      for (final i in order.items) {
        if (i.id.toString() == scanned || i.productId.toString() == scanned) {
          item = i;
          break;
        }
      }

      if (item != null) {
        if (item.isPacked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ئەم کاڵایە پێشتر پاکەتکراوە')),
          );
        } else {
          _togglePack(item, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کۆدی کاڵاکە لەم پسوڵەیەدا نەدۆزرایەوە')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'stock.pack',
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersToPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('پاکەتکردنی پسوڵەی #${widget.orderId}', style: AppTextStyles.h2),
        actions: [
          ordersAsync.maybeWhen(
            data: (orders) {
              WarehouseOrderModel? foundOrder;
              for (final o in orders) {
                if (o.id.toString() == widget.orderId || o.orderNumber == widget.orderId) {
                  foundOrder = o;
                  break;
                }
              }
              if (foundOrder != null) {
                final WarehouseOrderModel currentOrder = foundOrder;
                return IconButton(
                  icon: const Icon(AppIcons.scan),
                  onPressed: () => _onScanBarcode(currentOrder),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: AppSpacing.md),
              const Text('هەڵەیەک ڕوویدا لە بارکردنی پسوڵە'),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => ref.invalidate(ordersToPackProvider),
                child: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
        data: (orders) {
          WarehouseOrderModel? foundOrder;
          for (final o in orders) {
            if (o.id.toString() == widget.orderId || o.orderNumber == widget.orderId) {
              foundOrder = o;
              break;
            }
          }

          if (foundOrder == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'پسوڵەکە نەدۆزرایەوە',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'پێدەچێت ئەم پسوڵەیە پێشتر ئامادەکرابێت یان گوازرابێتەوە.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('گەڕانەوە بۆ لای پسوڵەکان'),
                    ),
                  ],
                ),
              ),
            );
          }

          final WarehouseOrderModel currentOrder = foundOrder;
          final int totalItemsCount = currentOrder.items.length;
          final int packedItemsCount = currentOrder.items.where((e) => e.isPacked).length;
          final bool isAnyPacked = packedItemsCount > 0;

          return Column(
            children: [
              _buildOrderSummary(theme, currentOrder, packedItemsCount, totalItemsCount),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: currentOrder.items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    final isPacked = item.isPacked;
                    final isItemLoading = _packingItemIds.contains(item.id);

                    return AppCard(
                      child: Row(
                        children: [
                          if (isItemLoading)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            Checkbox(
                              value: isPacked,
                              activeColor: AppColors.success,
                              checkColor: Colors.white,
                              onChanged: (value) {
                                if (value != null) {
                                  _togglePack(item, value);
                                }
                              },
                            ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    decoration: isPacked ? TextDecoration.lineThrough : null,
                                    color: isPacked ? Colors.grey : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'بڕ: ${item.quantity} دانە',
                                  style: AppTextStyles.caption.copyWith(
                                    color: isPacked ? Colors.grey : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildBottomAction(theme, currentOrder, isAnyPacked),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme, WarehouseOrderModel order, int packedCount, int totalCount) {
    final bool isAllPacked = packedCount == totalCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('کڕیار: ${order.customerName}', style: AppTextStyles.bodyBold),
              Text('بەروار: ${order.createdAt.split('T').first}', style: AppTextStyles.caption),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAllPacked ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$packedCount / $totalCount تەواوبووە',
              style: AppTextStyles.bodyBold.copyWith(
                color: isAllPacked ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(ThemeData theme, WarehouseOrderModel order, bool isAnyPacked) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: _isSubmittingReady
            ? const Center(child: CircularProgressIndicator())
            : AppButton(
                text: 'پسوڵەکە ئامادەیە (Ready)',
                onPressed: isAnyPacked ? () => _submitReady(order) : null,
                size: AppButtonSize.lg,
              ),
      ),
    );
  }
}
