import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/warehouse_order_model.dart';
import '../providers/warehouse_provider.dart';

class PackOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PackOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<PackOrderScreen> createState() => _PackOrderScreenState();
}

class _PackOrderScreenState extends ConsumerState<PackOrderScreen> {
  final Map<int, bool> _optimisticPackedStates = {};
  final Set<int> _pendingItemIds = {};
  bool _isSubmittingReady = false;

  Future<void> _togglePack(WarehouseOrderItemModel item, bool value) async {
    // 1. Instant Optimistic UI Update (0ms delay)
    setState(() {
      _optimisticPackedStates[item.id] = value;
      _pendingItemIds.add(item.id);
    });

    try {
      await ref.read(warehouseActionsProvider).packItem(item.id, value);
    } catch (e) {
      if (mounted) {
        // Rollback state if server returns error
        setState(() {
          _optimisticPackedStates[item.id] = !value;
        });
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
          _pendingItemIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _packAll(WarehouseOrderModel order) async {
    final unpackedItems = order.items.where((item) {
      final isPacked = _optimisticPackedStates[item.id] ?? item.isPacked;
      return !isPacked;
    }).toList();

    if (unpackedItems.isEmpty) return;

    setState(() {
      for (final item in unpackedItems) {
        _optimisticPackedStates[item.id] = true;
        _pendingItemIds.add(item.id);
      }
    });

    for (final item in unpackedItems) {
      ref.read(warehouseActionsProvider).packItem(item.id, true).catchError((e) {
        if (mounted) {
          setState(() {
            _optimisticPackedStates[item.id] = false;
          });
        }
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _pendingItemIds.remove(item.id);
          });
        }
      });
    }
  }

  Future<void> _submitReady(WarehouseOrderModel order) async {
    if (_isSubmittingReady) return;

    // Check if some items are not packed and confirm partial ready
    final bool hasUnpacked = order.items.any((e) => !(_optimisticPackedStates[e.id] ?? e.isPacked));
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
        AppSnackbar.show(
          context,
          message: 'پسوڵەکە بە سەرکەوتوویی بە ئامادەکراو تۆمارکرا',
          type: SnackbarType.success,
        );
        ref.invalidate(ordersToPackProvider);
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
        final currentPacked = _optimisticPackedStates[item.id] ?? item.isPacked;
        if (currentPacked) {
          AppSnackbar.show(
            context,
            message: 'ئەم کاڵایە پێشتر پاکەتکراوە',
            type: SnackbarType.info,
          );
        } else {
          _togglePack(item, true);
        }
      } else {
        AppSnackbar.show(
          context,
          message: 'کۆدی کاڵاکە لەم پسوڵەیەدا نەدۆزرایەوە',
          type: SnackbarType.warning,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.invalidate(ordersToPackProvider);
        }
      },
      child: PermissionGuard(
        permission: 'stock.pack',
        child: _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersToPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'پاکەتکردنی پسوڵەی #${widget.orderId}',
          style: AppTextStyles.h2,
        ),
        actions: [
          ordersAsync.maybeWhen(
            data: (orders) {
              WarehouseOrderModel? foundOrder;
              for (final o in orders) {
                if (o.id.toString() == widget.orderId ||
                    o.orderNumber == widget.orderId) {
                  foundOrder = o;
                  break;
                }
              }
              if (foundOrder != null) {
                final WarehouseOrderModel currentOrder = foundOrder;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.done_all),
                      tooltip: 'پاکەتکردنی هەمووی',
                      onPressed: () => _packAll(currentOrder),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.scan),
                      tooltip: 'سکانی باڕکۆد',
                      onPressed: () => _onScanBarcode(currentOrder),
                    ),
                  ],
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
        error: (err, stack) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ErrorState(
                  title: 'هەڵەیەک ڕوویدا لە بارکردنی پسوڵە',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () => ref.invalidate(ordersToPackProvider),
                ),
              ),
            ),
          ),
        ),
        data: (orders) {
          WarehouseOrderModel? foundOrder;
          for (final o in orders) {
            if (o.id.toString() == widget.orderId ||
                o.orderNumber == widget.orderId) {
              foundOrder = o;
              break;
            }
          }

          if (foundOrder == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  title: 'پسوڵەکە نەدۆزرایەوە',
                  message: 'پێدەچێت ئەم پسوڵەیە پێشتر ئامادەکرابێت یان گوازرابێتەوە.',
                  icon: Icons.check_circle_outline,
                  buttonText: 'گەڕانەوە بۆ لای پسوڵەکان',
                  onAction: () => Navigator.pop(context),
                ),
              ),
            );
          }

          final WarehouseOrderModel currentOrder = foundOrder;
          final int totalItemsCount = currentOrder.items.length;
          final int packedItemsCount = currentOrder.items
              .where((e) => _optimisticPackedStates[e.id] ?? e.isPacked)
              .length;
          final bool isAnyPacked = packedItemsCount > 0;

          return Column(
            children: [
              _buildOrderSummary(
                theme,
                currentOrder,
                packedItemsCount,
                totalItemsCount,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: currentOrder.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    final isPacked = _optimisticPackedStates[item.id] ?? item.isPacked;
                    final isPending = _pendingItemIds.contains(item.id);

                    return AppCard(
                      child: Row(
                        children: [
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
                                    decoration: isPacked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isPacked ? Colors.grey : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'بڕ: ${item.quantity} دانە',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isPacked
                                            ? Colors.grey
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    ],
                                  ],
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

  Widget _buildOrderSummary(
    ThemeData theme,
    WarehouseOrderModel order,
    int packedCount,
    int totalCount,
  ) {
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
              Text(
                'کڕیار: ${order.customerName}',
                style: AppTextStyles.bodyBold,
              ),
              Text(
                'بەروار: ${order.createdAt.split('T').first}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAllPacked
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
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

  Widget _buildBottomAction(
    ThemeData theme,
    WarehouseOrderModel order,
    bool isAnyPacked,
  ) {
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
