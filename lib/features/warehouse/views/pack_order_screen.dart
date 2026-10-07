import 'dart:async';
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
import '../../orders/providers/orders_provider.dart';
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

  // 10-Second Timer/Sync variables:
  final Map<int, bool> _unsavedChanges = {};
  int _secondsRemaining = 0;
  bool _timerPausedForRetry = false;
  bool _isSaving = false;
  Timer? _debounceTimer;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _triggerDebouncedAutoSave() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _secondsRemaining = 10;
        _timerPausedForRetry = false;
      });
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });

    _debounceTimer = Timer(const Duration(seconds: 10), () {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _secondsRemaining = 0;
        });
      }
      _triggerAutoSave();
    });
  }

  Future<void> _triggerAutoSave() async {
    if (_unsavedChanges.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
      _timerPausedForRetry = false;
    });

    final List<Map<String, dynamic>> itemsPayload = _unsavedChanges.entries.map((e) {
      return {
        'order_item_id': e.key,
        'packed': e.value,
      };
    }).toList();

    try {
      await ref.read(warehouseActionsProvider).packItems(itemsPayload);
      
      if (mounted) {
        setState(() {
          _unsavedChanges.clear();
          _isSaving = false;
          _secondsRemaining = 0;
          _timerPausedForRetry = false;
        });
        
        AppSnackbar.show(
          context,
          message: 'نوێکارییەکانی پاکەتکردن بە سەرکەوتوویی پاشەکەوت کران',
          type: SnackbarType.success,
        );

        ref.invalidate(ordersToPackProvider);
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) {
        setState(() {
          _timerPausedForRetry = true;
          _secondsRemaining = 10; // Freeze at 10 for manual retry trigger
          _isSaving = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('کێشە لە پاشەکەوتکردنی دەستەجەیی'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _triggerAutoSave();
                },
                child: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _togglePack(WarehouseOrderItemModel item, bool value, List<WarehouseOrderItemModel> allItems) {
    setState(() {
      _optimisticPackedStates[item.id] = value;
      if (item.isPacked == value) {
        _unsavedChanges.remove(item.id);
      } else {
        _unsavedChanges[item.id] = value;
      }
    });

    // Check if ALL items in the entire order are packed (using the latest state including unsaved changes)
    final bool allPacked = allItems.every((e) {
      return _unsavedChanges.containsKey(e.id)
          ? _unsavedChanges[e.id]!
          : (_optimisticPackedStates[e.id] ?? e.isPacked);
    });

    if (allPacked && _unsavedChanges.isNotEmpty) {
      _debounceTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _secondsRemaining = 0;
        _timerPausedForRetry = false;
      });
      _triggerAutoSave();
    } else if (_unsavedChanges.isNotEmpty) {
      _triggerDebouncedAutoSave();
    } else {
      _debounceTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _secondsRemaining = 0;
        _timerPausedForRetry = false;
      });
    }
  }

  Future<void> _submitReady(WarehouseOrderModel order) async {
    if (_isSubmittingReady) return;

    // Force save any pending changes before allowing order readiness
    if (_unsavedChanges.isNotEmpty) {
      _debounceTimer?.cancel();
      _countdownTimer?.cancel();
      await _triggerAutoSave();
      if (_unsavedChanges.isNotEmpty) {
        // If save failed or changes couldn't be uploaded, halt ready submission
        return;
      }
    }

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
        ref.invalidate(ordersListProvider);
        ref.invalidate(readyOrdersForDeliveryProvider);
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
      WarehouseOrderItemModel? item;
      for (final i in order.items) {
        if (i.id.toString() == scanned || i.productId.toString() == scanned) {
          item = i;
          break;
        }
      }

      if (item != null) {
        final currentPacked = _unsavedChanges.containsKey(item.id)
            ? _unsavedChanges[item.id]!
            : (_optimisticPackedStates[item.id] ?? item.isPacked);
        if (currentPacked) {
          AppSnackbar.show(
            context,
            message: 'ئەم کاڵایە پێشتر پاکەتکراوە',
            type: SnackbarType.info,
          );
        } else {
          _togglePack(item, true, order.items);
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

  List<Widget> _buildActions(AsyncValue<List<WarehouseOrderModel>> ordersAsync) {
    final List<Widget> actionWidgets = [];

    // Red/Orange auto-save countdown timer badge matching the exact project styles
    if (_secondsRemaining > 0 || _timerPausedForRetry) {
      actionWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: InkWell(
            onTap: _timerPausedForRetry ? _triggerAutoSave : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _timerPausedForRetry
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _timerPausedForRetry
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _timerPausedForRetry ? Icons.refresh : Icons.timer_outlined,
                    size: 16,
                    color: _timerPausedForRetry ? AppColors.danger : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_secondsRemaining',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: _timerPausedForRetry ? AppColors.danger : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isSaving) {
      actionWidgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          ),
        ),
      );
    }

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
          final currentOrder = foundOrder;
          actionWidgets.add(
            IconButton(
              icon: const Icon(AppIcons.scan),
              tooltip: 'سکانی باڕکۆد',
              onPressed: () => _onScanBarcode(currentOrder),
            ),
          );
        }
      },
      orElse: () {},
    );

    return actionWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'stock.pack',
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (_debounceTimer?.isActive == true) {
            _debounceTimer?.cancel();
            _triggerAutoSave();
          }
          if (didPop) {
            ref.invalidate(ordersToPackProvider);
          }
        },
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
          'پاکەتکردنی #${widget.orderId}',
          style: AppTextStyles.h2,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: _buildActions(ordersAsync),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersToPackProvider);
          await ref.read(ordersToPackProvider.future);
        },
        child: ordersAsync.when(
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
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
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
                    ),
                  ),
                ),
              );
            }
  
            final WarehouseOrderModel currentOrder = foundOrder;
            final int totalItemsCount = currentOrder.items.length;
            final int packedItemsCount = currentOrder.items
                .where((e) {
                  return _unsavedChanges.containsKey(e.id)
                      ? _unsavedChanges[e.id]!
                      : (_optimisticPackedStates[e.id] ?? e.isPacked);
                })
                .length;
            final bool isAllPacked = packedItemsCount == totalItemsCount;
  
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    itemCount: currentOrder.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = currentOrder.items[index];
                    
                    // Unsaved local changes take complete priority over server state to prevent active loss
                    final isPacked = _unsavedChanges.containsKey(item.id)
                        ? _unsavedChanges[item.id]!
                        : (_optimisticPackedStates[item.id] ?? item.isPacked);
                        
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
                                _togglePack(item, value, currentOrder.items);
                              }
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => _showProductImageFullScreen(context, item),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      item.sku != null && item.sku!.trim().isNotEmpty
                                          ? '${item.productName} (${item.sku})'
                                          : item.productName,
                                      style: AppTextStyles.bodyBold.copyWith(
                                        decoration: isPacked
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isPacked ? Colors.grey : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'بڕ: ${item.quantity} ${item.productUnit ?? 'دانە'}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: isPacked
                                              ? Colors.grey
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.productUnit ?? 'دانە'} = ${item.unitsPerCarton ?? 1} دانە',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.grey,
                                        fontSize: 11,
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
              _buildBottomAction(theme, currentOrder, isAllPacked),
            ],
          );
        },
      ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کڕیار: ${order.customerName}',
                  style: AppTextStyles.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'مەندوب: ${order.salesmanName} • بەروار: ${Formatters.kurdishDayAndDate(order.createdAt)}',
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
    bool isAllPacked,
  ) {
    if (!isAllPacked || _isSaving || _unsavedChanges.isNotEmpty || _secondsRemaining > 0) {
      return const SizedBox.shrink();
    }
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
                onPressed: () => _submitReady(order),
                size: AppButtonSize.lg,
              ),
      ),
    );
  }

  void _showProductImageFullScreen(BuildContext context, WarehouseOrderItemModel item) {
    String? rawImagePath;
    try {
      rawImagePath = item.productImagePath;
    } catch (_) {}

    final bool hasImage = rawImagePath != null && rawImagePath.trim().isNotEmpty;
    final String? resolvedUrl = hasImage ? _resolveImageUrl(rawImagePath.trim()) : null;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          child: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Stack(
                children: [
                  // Image/Content viewer area
                  Center(
                    child: resolvedUrl != null
                        ? InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              resolvedUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      size: 80,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                      child: Text(
                                        item.productName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Rudaw',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'وێنەی کاڵاکە بارنەبوو یان بەردەست نییە',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: 'Rudaw',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 100,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rudaw',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'هیچ وێنەیەک بۆ ئەم کاڵایە تۆمار نەکراوە',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Rudaw',
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Top Header Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                         gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return 'https://pos.gardi.click$cleanPath';
  }
}
