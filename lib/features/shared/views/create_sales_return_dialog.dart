import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';

class CreateSalesReturnDialog extends ConsumerStatefulWidget {
  final OrderModel order;

  const CreateSalesReturnDialog({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<CreateSalesReturnDialog> createState() =>
      _CreateSalesReturnDialogState();
}

class _CreateSalesReturnDialogState
    extends ConsumerState<CreateSalesReturnDialog> {
  final Map<int, int> _returnQuantities = {};
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _itemReasonControllers = {};
  final TextEditingController _generalReasonController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      _returnQuantities[item.id] = 0;
      _qtyControllers[item.id] = TextEditingController(text: '0');
      _itemReasonControllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _generalReasonController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final c in _itemReasonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateQuantity(int itemId, int newQty, int maxQty) {
    final clamped = newQty.clamp(0, maxQty);
    setState(() {
      _returnQuantities[itemId] = clamped;
      _qtyControllers[itemId]?.text = clamped.toString();
      _errorMessage = null;
    });
  }

  double _calculateTotalReturnAmount() {
    double total = 0.0;
    for (final item in widget.order.items) {
      final qty = _returnQuantities[item.id] ?? 0;
      total += qty * item.unitPrice;
    }
    return total;
  }

  int _calculateTotalReturnCount() {
    return _returnQuantities.values.fold<int>(0, (sum, q) => sum + q);
  }

  String? _validate() {
    final totalQty = _calculateTotalReturnCount();
    if (totalQty <= 0) {
      return 'تکایە لانیکەم بڕی کاڵایەک بۆ گەڕاندنەوە دیاری بکە';
    }

    for (final item in widget.order.items) {
      final maxQty = item.quantity.toInt();
      final qty = _returnQuantities[item.id] ?? 0;
      if (qty < 0) {
        return 'بڕی گەڕاندنەوە بۆ "${item.productName}" ناتوانێت کەمتر بێت لە سفر';
      }
      if (qty > maxQty) {
        return 'بڕی گەڕاندنەوە بۆ "${item.productName}" زیاترە لە بڕی کڕدراو ($maxQty)';
      }
    }

    return null;
  }

  Future<void> _submitReturn() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final List<Map<String, dynamic>> returnItems = [];
    for (final item in widget.order.items) {
      final qty = _returnQuantities[item.id] ?? 0;
      if (qty > 0) {
        final itemMap = <String, dynamic>{
          'sales_order_item_id': item.id,
          'quantity': qty,
        };
        final itemReason = _itemReasonControllers[item.id]?.text.trim();
        if (itemReason != null && itemReason.isNotEmpty) {
          itemMap['reason'] = itemReason;
        }
        returnItems.add(itemMap);
      }
    }

    final String idempotencyKey =
        'ret_${widget.order.id}_${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'sales_order_id': widget.order.id,
      'items': returnItems,
      'idempotency_key': idempotencyKey,
    };
    final genReason = _generalReasonController.text.trim();
    if (genReason.isNotEmpty) {
      payload['reason'] = genReason;
    }

    try {
      await ref.read(salesReturnActionsProvider).createSalesReturn(payload);

      if (mounted) {
        ref.invalidate(singleOrderProvider(widget.order.id.toString()));
        ref.invalidate(salesReturnsListProvider);
        ref.invalidate(ordersListProvider);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = _calculateTotalReturnAmount();
    final totalQty = _calculateTotalReturnCount();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_return_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'گەڕاندنەوەی کاڵا',
                            style: AppTextStyles.h2,
                          ),
                          Text(
                            'پسوڵەی #${widget.order.orderNumber.isNotEmpty ? widget.order.orderNumber : widget.order.id}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Order Items List
              Expanded(
                child: widget.order.items.isEmpty
                    ? const Center(
                        child: Text('هیچ کاڵایەک لەم پسوڵەیەدا نییە'),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.order.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = widget.order.items[index];
                          final maxQty = item.quantity.toInt();
                          final currentQty = _returnQuantities[item.id] ?? 0;
                          final itemSubtotal = currentQty * item.unitPrice;

                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.productName,
                                        style: AppTextStyles.bodyBold,
                                      ),
                                    ),
                                    Text(
                                      Formatters.currency(item.unitPrice),
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'بڕی کڕدراو: $maxQty دانە',
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      'کۆی گەڕاوە: ${Formatters.currency(itemSubtotal)}',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: currentQty > 0
                                            ? AppColors.primary
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    const Text(
                                      'بڕی گەڕاندنەوە: ',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: AppColors.danger,
                                      ),
                                      onPressed: currentQty > 0
                                          ? () => _updateQuantity(
                                                item.id,
                                                currentQty - 1,
                                                maxQty,
                                              )
                                          : null,
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        controller: _qtyControllers[item.id],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (val) {
                                          final parsed = int.tryParse(val) ?? 0;
                                          _updateQuantity(
                                            item.id,
                                            parsed,
                                            maxQty,
                                          );
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: currentQty < maxQty
                                          ? () => _updateQuantity(
                                                item.id,
                                                currentQty + 1,
                                                maxQty,
                                              )
                                          : null,
                                    ),
                                    const Spacer(),
                                    if (currentQty > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$currentQty لە $maxQty',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (currentQty > 0) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  TextFormField(
                                    controller: _itemReasonControllers[item.id],
                                    decoration: const InputDecoration(
                                      hintText:
                                          'هۆکاری گەڕاندنەوەی ئەم کاڵایە (ئارەزوومەندانە)...',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // General Reason Field
              AppTextField(
                controller: _generalReasonController,
                hintText: 'هۆکاری گشتیی گەڕاندنەوە (ئارەزوومەندانە)...',
              ),

              const SizedBox(height: AppSpacing.sm),

              // Total Summary & Submit
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'کۆی کاڵای گەڕاوە: $totalQty دانە',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'کۆی بڕی پارە: ${Formatters.currency(totalAmount)}',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        AppButton(
                          text: 'پاشگەزبوونەوە',
                          type: AppButtonType.text,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          text: 'تۆمارکردنی گەڕاندنەوە',
                          isLoading: _isSubmitting,
                          onPressed: totalQty > 0 && !_isSubmitting
                              ? _submitReturn
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
