import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'create_sales_return_dialog.dart';
import 'map_picker_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final Set<int> _checkedItemIds = {};
  final TextEditingController _cashVanDiscountController =
      TextEditingController();
  int? _checklistOrderId;
  int? _discountOrderId;
  bool _isSubmittingCashVanDelivery = false;

  void _syncCheckedItems(OrderModel order) {
    if (_checklistOrderId == order.id) return;
    _checklistOrderId = order.id;
    _checkedItemIds
      ..clear()
      ..addAll(
        order.items.where((item) => item.isPacked).map((item) => item.id),
      );
  }

  void _syncCashVanDiscount(OrderModel order) {
    if (_discountOrderId == order.id) return;
    _discountOrderId = order.id;
    _cashVanDiscountController.text = order.discountAmount.toInt().toString();
  }

  @override
  void dispose() {
    _cashVanDiscountController.dispose();
    super.dispose();
  }

  Future<void> _handleCancelOrder(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('هەڵوەشاندنەوەی پسوڵە')),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context, false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: const Text(
          'ئایا دڵنیایت لە هەڵوەشاندنەوەی ئەم پسوڵەیە؟ بڕە حجزکراوەکانی کۆگا ئازاد دەکرێن.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بەڵێ، هەڵیوەشێنەرەوە'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref
            .read(orderActionsProvider)
            .updateOrderStatus(widget.orderId, OrderModel.statusCancelled);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پسوڵەکە بە سەرکەوتوویی هەڵوەشێندرایەوە'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('هەڵە')),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: Text(e.toString().replaceAll('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCreateReturn(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateSalesReturnDialog(order: order),
    );

    if (result == true && context.mounted) {
      ref.invalidate(singleOrderProvider(order.id.toString()));
      ref.invalidate(salesReturnsListProvider);
      ref.invalidate(ordersListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کاڵاکان بە سەرکەوتوویی گەڕێندرانەوە'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleCashVanArrival(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) async {
    final amountBeforeDiscount =
        (order.subtotal - order.permanentDiscountAmount).clamp(
          0,
          double.infinity,
        );
    final discountAmount = (int.tryParse(_cashVanDiscountController.text) ?? 0)
        .clamp(0, amountBeforeDiscount.toInt())
        .toInt();

    setState(() {
      _isSubmittingCashVanDelivery = true;
    });
    try {
      await ref
          .read(orderActionsProvider)
          .updateOrderStatus(
            order.id.toString(),
            OrderModel.statusDelivered,
            extraData: {
              'discount_amount': discountAmount,
              'checked_item_ids': _checkedItemIds.toList(),
            },
          );
      if (!context.mounted) return;
      ref.invalidate(singleOrderProvider(order.id.toString()));
      ref.invalidate(ordersListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پسوڵەکە بە سەرکەوتوویی گەیشت'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCashVanDelivery = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final orderAsync = ref.watch(singleOrderProvider(widget.orderId));
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktopMin;

    return Scaffold(
      appBar: AppBar(
        title: Text('پسوڵەی #${widget.orderId}', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_return_outlined),
            tooltip: 'کاڵا ڕاگەڕێندراوەکان',
            onPressed: () => context.push('/sales-returns'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(singleOrderProvider(widget.orderId));
          await ref.read(singleOrderProvider(widget.orderId).future);
        },
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('هەڵەیەک ڕوویدا لە بارکردنی زانیاری پسوڵە'),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(singleOrderProvider(widget.orderId)),
                        child: const Text('دووبارە هەوڵبدەرەوە'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          data: (order) {
            if (order == null) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: Text('هیچ پسوڵەیەک نەدۆزرایەوە'),
                    ),
                  ),
                ),
              );
            }

            _syncCheckedItems(order);
            _syncCashVanDiscount(order);
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildMainContent(context, ref, order),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 1,
                          child: _buildSidePanel(context, ref, order),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildMainContent(context, ref, order),
                        const SizedBox(height: AppSpacing.md),
                        _buildSidePanel(context, ref, order),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) {
    final currentUser = ref.watch(authProvider).user;
    final isDriver = currentUser?.isDriver ?? false;
    final isCashVanCheckout =
        (currentUser?.isCashVanSalesman ?? false) &&
        order.status == OrderModel.statusInDelivery;
    final allCashVanItemsChecked =
        order.items.isNotEmpty &&
        order.items.every((item) => _checkedItemIds.contains(item.id));
    final amountBeforeCashVanDiscount =
        (order.subtotal - order.permanentDiscountAmount).clamp(
          0,
          double.infinity,
        );
    final cashVanDiscount = (int.tryParse(_cashVanDiscountController.text) ?? 0)
        .clamp(0, amountBeforeCashVanDiscount.toInt())
        .toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.hasReturns) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'ئاگاداری: ئەم پسوڵەیە کاڵای گەڕاوەی لەگەڵدایە! (${order.returnedItems.length} جۆر - ${order.totalReturnQuantity} دانە)',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.amber.shade300
                              : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isDriver) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ئاگاداری بۆ شۆفێر: تکایە لە کاتی گەیاندنی ئەم پسوڵەیە، دڵنیابە لە وەرگرتنەوەی ئەم کاڵا گەڕاوانە لە کڕیار.',
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_return_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'کاڵا گەڕاوەکان (Returned Items)',
                          style: AppTextStyles.h3,
                        ),
                      ],
                    ),
                    Text(
                      '${order.returnedItems.length} جۆر کاڵا',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.returnedItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final theme = Theme.of(context);
                    final item = order.returnedItems[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.keyboard_return_rounded,
                            size: 20,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      title: Text(
                        item.productName,
                        style: AppTextStyles.bodyBold,
                      ),
                      subtitle: Text(
                        '${item.quantity.toInt()} ${item.productUnit ?? 'دانە'}   •   ${Formatters.currency(item.unitPrice)}${item.reason != null && item.reason!.isNotEmpty ? "   •   هۆکار: ${item.reason}" : ""}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        Formatters.currency(item.subtotal),
                        style: AppTextStyles.price.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'کۆی بڕی گەڕاوە',
                        style: AppTextStyles.bodyBold,
                      ),
                      Text(
                        Formatters.currency(order.totalReturnAmount),
                        style: AppTextStyles.price.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('کاڵاکان', style: AppTextStyles.h3),
                  Text(
                    '${order.items.length} کاڵا',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (order.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('هیچ کاڵایەک لەم پسوڵەیەدا نییە')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final theme = Theme.of(context);
                    final item = order.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: isCashVanCheckout
                          ? Checkbox(
                              value: _checkedItemIds.contains(item.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _checkedItemIds.add(item.id);
                                  } else {
                                    _checkedItemIds.remove(item.id);
                                  }
                                });
                              },
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: item.isPacked
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  item.isPacked
                                      ? Icons.check_circle
                                      : Icons.inventory_2_outlined,
                                  size: 20,
                                  color: item.isPacked
                                      ? (theme.brightness == Brightness.dark
                                            ? AppColors.successDark
                                            : AppColors.success)
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                      title: Text(
                        item.productName,
                        style: AppTextStyles.bodyBold,
                      ),
                      subtitle: Text(
                        '${item.productUnit ?? 'دانە'} = ${item.unitsPerCarton ?? 1} دانە   •   ${Formatters.currency(item.unitPrice)}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency(item.subtotal),
                            style: AppTextStyles.price,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity.toInt()} ${item.productUnit ?? 'دانە'}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(thickness: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی بڕ', style: AppTextStyles.bodyMedium),
                    Text(
                      Formatters.currency(order.subtotal),
                      style: AppTextStyles.bodyBold,
                    ),
                  ],
                ),
              ),
              if (order.permanentDiscountAmount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'داشکاندنی بەردەوامی کڕیار (${order.permanentDiscountPercent.toStringAsFixed(1)}%)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '- ${Formatters.currency(order.permanentDiscountAmount)}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isCashVanCheckout)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('داشکان', style: AppTextStyles.bodyMedium),
                      ),
                      SizedBox(
                        width: 150,
                        child: AppTextField(
                          controller: _cashVanDiscountController,
                          keyboardType: TextInputType.number,
                          labelText: 'بڕی داشکاندن',
                          hintText: '0',
                          textAlign: TextAlign.end,
                          customDecoration: InputDecoration(
                            hintText: '0',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                )
              else if (order.discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.discountType == 'FIXED'
                              ? 'داشکاندنی پسوڵە (بڕی دیاریکراو)'
                              : 'داشکاندنی پسوڵە (${order.discountPercent}%)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '- ${Formatters.currency(order.discountAmount)}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی گشتی', style: AppTextStyles.bodyLarge),
                    Text(
                      Formatters.currency(
                        isCashVanCheckout
                            ? (amountBeforeCashVanDiscount - cashVanDiscount)
                                  .clamp(0, double.infinity)
                            : order.totalAmount,
                      ),
                      style: AppTextStyles.priceLarge,
                    ),
                  ],
                ),
              ),
              if (isCashVanCheckout && allCashVanItemsChecked) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmittingCashVanDelivery
                        ? null
                        : () => _handleCashVanArrival(context, ref, order),
                    icon: _isSubmittingCashVanDelivery
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.where_to_vote_outlined),
                    label: const Text('گەیشت؟'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تێبینی', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(order.notes!, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) {
    final customerName = order.customerName;
    final customerAddress = order.customerAddress;
    final salesmanName = order.salesmanName;
    final warehouseName = order.warehouseName;

    final currentUser = ref.watch(authProvider).user;
    final isSalesman = currentUser?.isSalesman ?? false;

    StatusBadgeType statusType = StatusBadgeType.warning;
    switch (order.status) {
      case OrderModel.statusDelivered:
        statusType = StatusBadgeType.success;
        break;
      case OrderModel.statusConfirmed:
      case OrderModel.statusPacking:
      case OrderModel.statusReady:
        statusType = StatusBadgeType.info;
        break;
      case OrderModel.statusInDelivery:
        statusType = StatusBadgeType.warning;
        break;
      case OrderModel.statusCancelled:
        statusType = StatusBadgeType.danger;
        break;
      case OrderModel.statusDraft:
      default:
        statusType = StatusBadgeType.warning;
        break;
    }

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('زانیاری پسوڵە', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow(context, 'کڕیار', customerName),
              _buildInfoRow(context, 'ناونیشان', customerAddress),
              _buildInfoRow(context, 'مەندوب', salesmanName),
              if (!isSalesman) _buildInfoRow(context, 'کۆگا', warehouseName),
              _buildInfoRow(
                context,
                'بەروار',
                Formatters.kurdishDayAndDate(order.createdAt),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text(
                    'شوێنی کڕیار لەسەر نەخشە',
                    style: TextStyle(fontSize: 12, fontFamily: 'KJino'),
                  ),
                  onPressed: () {
                    MapPickerDialog.showCustomerLocation(
                      context,
                      customerName: customerName,
                      customerAddress: customerAddress,
                      latitude: order.customerLatitude,
                      longitude: order.customerLongitude,
                      isReadOnly: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('دۆخی ئێستا', style: AppTextStyles.bodyMedium),
                  StatusBadge(label: order.localizedStatus, type: statusType),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کورتەی دارایی', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildInfoRow(
                context,
                'کۆی گشتی',
                Formatters.currency(order.totalAmount),
              ),
              _buildInfoRow(
                context,
                'داشکاندن',
                Formatters.currency(order.discountAmount),
              ),
              if (order.hasReturns)
                _buildInfoRow(
                  context,
                  'کۆی کاڵای گەڕاوە',
                  '-${Formatters.currency(order.totalReturnAmount)}',
                ),
            ],
          ),
        ),
        if (order.status == OrderModel.statusDraft ||
            ((currentUser?.isCashVanSalesman ?? false) &&
                order.status == OrderModel.statusInDelivery)) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'دستکاریی پسوڵە (Edit Order)',
            type: AppButtonType.outline,
            onPressed: () {
              context.push('/salesman/create-order', extra: order);
            },
          ),
        ],
        if (order.canCancel) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'هەڵوەشاندنەوەی پسوڵە (Cancel)',
            type: AppButtonType.danger,
            onPressed: () => _handleCancelOrder(context, ref),
          ),
        ],
        if (order.status == OrderModel.statusDelivered &&
            (ref.watch(authProvider).user?.isSalesman ?? false)) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: 'گەڕاندنەوەی کاڵا',
            type: AppButtonType.outline,
            onPressed: () => _handleCreateReturn(context, ref, order),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
