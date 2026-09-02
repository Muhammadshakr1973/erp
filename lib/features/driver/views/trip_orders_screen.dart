import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/driver_providers.dart';

class TripOrdersScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripOrdersScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripOrdersScreen> createState() => _TripOrdersScreenState();
}

class _TripOrdersScreenState extends ConsumerState<TripOrdersScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final intParsedId = int.tryParse(widget.tripId) ?? 0;
    final tripDetailAsync = ref.watch(tripDetailProvider(intParsedId));

    return Scaffold(
      appBar: AppBar(
        title: Text('وردەکاری گەشت #$intParsedId', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(tripDetailProvider(intParsedId)),
          ),
        ],
      ),
      body: tripDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'کێشەیەک لە بارکردنی گەشتەکە ڕوویدا',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(err.toString(), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(tripDetailProvider(intParsedId)),
                  child: const Text('دووبارە هەوڵبدەرەوە'),
                ),
              ],
            ),
          ),
        ),
        data: (trip) {
          int total = trip.orders.length;
          int delivered = trip.orders.where((o) => o.status == 'DELIVERED').length;
          int failed = trip.orders.where((o) => o.status == 'FAILED').length;
          int pending = total - delivered - failed;

          return Column(
            children: [
              _buildTripSummary(total, delivered, pending, failed),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: trip.orders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final tripOrder = trip.orders[index];
                    final order = tripOrder.order;
                    final customerName = _getCustomerName(order?.customer);
                    final isPending = tripOrder.status == 'PENDING';

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                customerName,
                                style: AppTextStyles.bodyBold,
                              ),
                              StatusBadge(
                                label: _getOrderStatusLabel(tripOrder.status),
                                type: _getOrderStatusBadgeType(tripOrder.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'پسوڵەی ژمارە ${order?.orderNumber ?? 'نادیار'}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                          if (tripOrder.notes != null && tripOrder.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'تێبینی: ${tripOrder.notes}',
                              style: AppTextStyles.caption.copyWith(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatCurrency(order?.totalAmount ?? 0)} د.ع',
                                style: AppTextStyles.price,
                              ),
                              if (isPending && !_isSubmitting)
                                Row(
                                  children: [
                                    AppButton(
                                      text: 'گەیشت',
                                      size: AppButtonSize.sm,
                                      type: AppButtonType.primary,
                                      onPressed: () => _showDeliverDialog(tripOrder),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    AppButton(
                                      text: 'شکست',
                                      size: AppButtonSize.sm,
                                      type: AppButtonType.danger,
                                      onPressed: () => _showFailDialog(tripOrder),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getCustomerName(dynamic customer) {
    if (customer == null) return 'کڕیاری نەناسراو';
    if (customer is Map) return customer['name']?.toString() ?? 'کڕیاری نەناسراو';
    return 'کڕیاری نەناسراو';
  }

  String _getOrderStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return 'گەیشتووە';
      case 'FAILED':
        return 'شکستی هێنا';
      default:
        return 'لە ڕێگادایە';
    }
  }

  StatusBadgeType _getOrderStatusBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return StatusBadgeType.success;
      case 'FAILED':
        return StatusBadgeType.danger;
      default:
        return StatusBadgeType.warning;
    }
  }

  Widget _buildTripSummary(int total, int delivered, int pending, int failed) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('هەموو', '$total'),
          _buildSummaryItem('گەیشتوو', '$delivered', AppColors.success),
          _buildSummaryItem('ماوە', '$pending', AppColors.warning),
          _buildSummaryItem('شکست', '$failed', AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h2.copyWith(
            color: color ?? AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(num amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\n))'), (match) => ',');
  }

  Future<void> _showDeliverDialog(dynamic tripOrder) async {
    final defaultAmount = tripOrder.order?.totalAmount ?? 0;
    final amountController = TextEditingController(text: defaultAmount.toString());
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('پەسەندکردنی گەیاندن'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'بڕی پارەی وەرگیراو (د.ع)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'تێبینییەکان (ئارەزوومەندانە)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('پاشگەزبوونەوە'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () async {
                  final amount = int.tryParse(amountController.text) ?? 0;
                  Navigator.of(context).pop();
                  _submitDeliver(tripOrder.id, amount, notesController.text);
                },
                child: const Text('تۆمارکردن'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitDeliver(int tripOrderId, int amount, String notes) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(driverActionsProvider).deliverOrder(
            tripOrderId: tripOrderId,
            receivedAmount: amount,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پسوڵەکە بە سەرکەوتوویی بە گەیەنراو تۆمارکرا'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      ref.invalidate(tripDetailProvider(int.parse(widget.tripId)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('شکست لێتۆمارکردن: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showFailDialog(dynamic tripOrder) async {
    final notesController = TextEditingController();
    String selectedReason = 'کڕیار لە شوێنەکە نەبوو';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تۆمارکردنی شکستی گەیاندن'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'کڕیار لە شوێنەکە نەبوو',
                            child: Text('کڕیار لە شوێنەکە نەبوو'),
                          ),
                          DropdownMenuItem(
                            value: 'ناونیشانی هەڵە',
                            child: Text('ناونیشانی هەڵە'),
                          ),
                          DropdownMenuItem(
                            value: 'کڕیار کاڵاکەی ڕەتکردەوە',
                            child: Text('کڕیار کاڵاکەی ڕەتکردەوە'),
                          ),
                          DropdownMenuItem(
                            value: 'کێشەی گواستنەوە',
                            child: Text('کێشەی گواستنەوە'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'هۆکاری شکست',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'تێبینییەکان (ئارەزوومەندانە)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('پاشگەزبوونەوە'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitFail(tripOrder.id, selectedReason, notesController.text);
                    },
                    child: const Text('پەسەندکردن'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitFail(int tripOrderId, String reason, String notes) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(driverActionsProvider).failOrder(
            tripOrderId: tripOrderId,
            failedReason: reason,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شکستی پسوڵەکە بە سەرکەوتوویی تۆمارکرا'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      ref.invalidate(tripDetailProvider(int.parse(widget.tripId)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('شکست لە تۆمارکردن: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
