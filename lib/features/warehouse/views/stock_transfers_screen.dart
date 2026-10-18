import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/stock_transfer_model.dart';
import '../providers/warehouse_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import 'create_van_transfer_dialog.dart';

class StockTransfersScreen extends ConsumerStatefulWidget {
  const StockTransfersScreen({super.key});

  @override
  ConsumerState<StockTransfersScreen> createState() =>
      _StockTransfersScreenState();
}

class _StockTransfersScreenState extends ConsumerState<StockTransfersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, VAN, GENERAL

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTransferReceiptDialog(StockTransferModel transfer) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Receipt Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'داخستن',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'پسوڵەی بارکردنی کاشڤان / گواستنەوە',
                              style: AppTextStyles.h3,
                            ),
                            Text(
                              'ژمارەی پسوڵە: ${transfer.transferNumber}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: transfer.isCompleted
                            ? 'تەواوکراو'
                            : (transfer.isCancelled ? 'هەڵوەشاوە' : 'چاوەڕوانکراو'),
                        type: transfer.isCompleted
                            ? StatusBadgeType.success
                            : (transfer.isCancelled
                                ? StatusBadgeType.danger
                                : StatusBadgeType.warning),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Metadata Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('کۆگای نێرەر:',
                                style: AppTextStyles.caption),
                            Text(transfer.fromWarehouseName,
                                style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('کۆگای وەرگر (کاشڤان):',
                                style: AppTextStyles.caption),
                            Text(transfer.toWarehouseName,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: Colors.orange,
                                )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('بەروار و کات:',
                                style: AppTextStyles.caption),
                            Text(
                              transfer.createdAt != null
                                  ? Formatters.dateTime(transfer.createdAt!)
                                  : 'دیاری نەکراوە',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                        if (transfer.creatorName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('کارمەندی بەڕێکەر:',
                                  style: AppTextStyles.caption),
                              Text(transfer.creatorName!,
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ],
                        if (transfer.notes != null &&
                            transfer.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('تێبینی:',
                                  style: AppTextStyles.caption),
                              Text(transfer.notes!,
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Items List Table
                  const Text('لیستی کاڵا دراوەکان بە کاشڤان:',
                      style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('ناوی کاڵا',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('باڕکۆد',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text('بڕ',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        ...transfer.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(item.productName,
                                      style: AppTextStyles.bodyMedium),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.productBarcode ?? '-',
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${item.quantity} ${item.productUnit ?? "دانە"}',
                                    textAlign: TextAlign.end,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Signature Blocks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('واژووی کارمەندی کۆگا',
                              style: AppTextStyles.caption),
                          const SizedBox(height: 24),
                          Container(
                            width: 120,
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('واژووی وەرگری کاشڤان',
                              style: AppTextStyles.caption),
                          const SizedBox(height: 24),
                          Container(
                            width: 120,
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transfersAsync = ref.watch(stockTransfersListProvider);
    final dashboardAsync = ref.watch(warehouseDashboardProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final activeWarehouseId = ref.watch(activeWarehouseIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: warehousesAsync.when(
          data: (warehouses) {
            final activeWarehouse = warehouses.firstWhere(
              (w) => w.id == activeWarehouseId,
              orElse: () => warehouses.firstWhere(
                (w) => w.id == dashboardAsync.asData?.value.warehouseId,
                orElse: () => warehouses.first,
              ),
            );

            if (warehouses.length <= 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بارکردنی کاشڤان و گواستنەوە', style: AppTextStyles.h2),
                  Text(activeWarehouse.name, style: AppTextStyles.caption),
                ],
              );
            }

            return PopupMenuButton<int>(
              tooltip: 'گۆڕینی کۆگای چالاک',
              initialValue: activeWarehouse.id,
              onSelected: (selectedId) {
                ref.read(activeWarehouseIdProvider.notifier).state = selectedId;
                ref.invalidate(warehouseDashboardProvider);
                ref.invalidate(ordersToPackProvider);
                ref.invalidate(warehouseStocksProvider);
                ref.invalidate(stockTransfersListProvider);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activeWarehouse.isReserve
                        ? Icons.inventory_2_outlined
                        : (activeWarehouse.isVan
                            ? Icons.local_shipping_outlined
                            : Icons.warehouse_outlined),
                    size: 20,
                    color: activeWarehouse.isReserve
                        ? Colors.purple
                        : (activeWarehouse.isVan
                            ? Colors.orange
                            : theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('بارکردنی کاشڤان و گواستنەوە',
                            style: AppTextStyles.h3),
                        Text(
                          activeWarehouse.name,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 22),
                ],
              ),
              itemBuilder: (ctx) {
                return warehouses.map((w) {
                  return PopupMenuItem<int>(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(
                          w.isReserve
                              ? Icons.inventory_2_outlined
                              : (w.isVan
                                  ? Icons.local_shipping_outlined
                                  : Icons.warehouse_outlined),
                          size: 18,
                          color: w.isReserve
                              ? Colors.purple
                              : (w.isVan
                                  ? Colors.orange
                                  : theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(w.name),
                      ],
                    ),
                  );
                }).toList();
              },
            );
          },
          loading: () =>
              const Text('بارکردنی کاشڤان و گواستنەوە', style: AppTextStyles.h2),
          error: (_, __) =>
              const Text('بارکردنی کاشڤان و گواستنەوە', style: AppTextStyles.h2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () => ref.invalidate(stockTransfersListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.local_shipping),
        label: const Text('گواستنەوە'),
        onPressed: () async {
          final wList = warehousesAsync.asData?.value ?? [];
          final currentW = (activeWarehouseId != null && wList.any((w) => w.id == activeWarehouseId))
              ? wList.firstWhere((w) => w.id == activeWarehouseId)
              : (dashboardAsync.asData?.value.warehouseId != null &&
                      wList.any((w) => w.id == dashboardAsync.asData!.value.warehouseId))
                  ? wList.firstWhere((w) => w.id == dashboardAsync.asData!.value.warehouseId)
                  : (wList.isNotEmpty ? wList.first : null);

          final warehouseId = currentW?.id ??
              activeWarehouseId ??
              dashboardAsync.asData?.value.warehouseId ??
              (wList.isNotEmpty ? wList.first.id : 1);
          final warehouseName = currentW?.name ??
              dashboardAsync.asData?.value.warehouseName ??
              'کۆگای سەرەکی';

          final newTransfer = await showDialog<StockTransferModel?>(
            context: context,
            builder: (ctx) => CreateVanTransferDialog(
              fromWarehouseId: warehouseId,
              fromWarehouseName: warehouseName,
            ),
          );

          if (newTransfer != null && mounted) {
            _showTransferReceiptDialog(newTransfer);
          }
        },
      ),
      body: transfersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'کێشەیەک ڕوویدا لە بارکردنی پسوڵەکانی گواستنەوە',
            message: Formatters.cleanError(err),
            retryText: 'دووبارە هەوڵبدەرەوە',
            onRetry: () => ref.invalidate(stockTransfersListProvider),
          ),
        ),
        data: (transfers) {
          final filtered = transfers.where((t) {
            final isVan = t.toWarehouseName.contains('کاشڤان') ||
                t.fromWarehouseName.contains('کاشڤان');
            if (_selectedFilter == 'VAN' && !isVan) return false;
            if (_selectedFilter == 'GENERAL' && isVan) return false;

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return t.transferNumber.toLowerCase().contains(q) ||
                  t.fromWarehouseName.toLowerCase().contains(q) ||
                  t.toWarehouseName.toLowerCase().contains(q) ||
                  (t.notes?.toLowerCase().contains(q) ?? false);
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(stockTransfersListProvider);
              await ref.read(stockTransfersListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                // Filter Segment & Search
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _searchController,
                        hintText: 'گەڕان بەپێی ژمارەی پسوڵە یان ناوی کاشڤان...',
                        prefixIcon: Icons.search,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ALL', label: Text('هەموو')),
                        ButtonSegment(value: 'VAN', label: Text('کاشڤان')),
                        ButtonSegment(value: 'GENERAL', label: Text('کۆگا')),
                      ],
                      selected: {_selectedFilter},
                      onSelectionChanged: (set) {
                        setState(() {
                          _selectedFilter = set.first;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: EmptyState(
                        title: 'هیچ پسوڵەیەکی بارکردن نییە',
                        message: 'دەتوانیت لە ڕێگەی دوگمەی خوارەوە کاڵا باربکەیت بۆ ئۆتۆمبێلی کاشڤان.',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                  )
                else
                  ...filtered.map((transfer) {
                    final isVan = transfer.toWarehouseName.contains('کاشڤان');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () => _showTransferReceiptDialog(transfer),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isVan
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isVan
                                    ? Icons.local_shipping_outlined
                                    : Icons.swap_horiz,
                                color: isVan
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        transfer.transferNumber,
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(
                                        label: transfer.isCompleted
                                            ? 'تەواوکراو'
                                            : (transfer.isCancelled
                                                ? 'هەڵوەشاوە'
                                                : 'چاوەڕوانکراو'),
                                        type: transfer.isCompleted
                                            ? StatusBadgeType.success
                                            : (transfer.isCancelled
                                                ? StatusBadgeType.danger
                                                : StatusBadgeType.warning),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${transfer.fromWarehouseName} ➔ ${transfer.toWarehouseName}',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'کۆی کاڵاکان: ${transfer.totalItemsCount} دانە (${transfer.items.length} جۆر) • ${transfer.createdAt != null ? Formatters.dateTime(transfer.createdAt!) : ""}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
