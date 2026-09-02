import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../driver/providers/driver_providers.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';

class CreateDeliveryTripDialog extends ConsumerStatefulWidget {
  const CreateDeliveryTripDialog({super.key});

  @override
  ConsumerState<CreateDeliveryTripDialog> createState() => _CreateDeliveryTripDialogState();
}

class _CreateDeliveryTripDialogState extends ConsumerState<CreateDeliveryTripDialog> {
  int? _selectedDriverId;
  DateTime _selectedDate = DateTime.now();
  final Set<int> _selectedOrderIds = <int>{};
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە شۆفێرێک دیاریبکە')),
      );
      return;
    }

    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە بەلایەنی کەم پسوڵەیەک هەڵبژێرە بۆ گەیاندن')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await ref.read(driverActionsProvider).createDeliveryTrip(
        driverId: _selectedDriverId!,
        tripDate: formattedDate,
        orderIds: _selectedOrderIds.toList(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('گەشتەکە بە سەرکەوتوویی دروستکرا و پسوڵەکان نێردران بۆ شۆفێر'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە لە دروستکردنی گەشت: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driversAsync = ref.watch(activeDriversProvider);
    final readyOrdersAsync = ref.watch(readyOrdersForDeliveryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ناردنی گەشتی نوێ', style: AppTextStyles.h2),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver Selection
                      const Text('شۆفێر *', style: AppTextStyles.bodyBold),
                      const SizedBox(height: AppSpacing.xs),
                      driversAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'کێشە لە وەرگرتنی لیستی شۆفێرەکان: $err',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => ref.invalidate(activeDriversProvider),
                              ),
                            ],
                          ),
                        ),
                        data: (drivers) {
                          if (drivers.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                              child: const Text(
                                'هیچ شۆفێرێکی چالاک نەدۆزرایەوە لە سیستەمدا.',
                                style: AppTextStyles.caption,
                              ),
                            );
                          }

                          return DropdownButtonFormField<int>(
                            value: _selectedDriverId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                              hintText: 'شۆفێرێک هەڵبژێرە...',
                            ),
                            items: drivers.map((d) {
                              return DropdownMenuItem<int>(
                                value: d.id,
                                child: Text(
                                  d.phone != null && d.phone!.isNotEmpty
                                      ? '${d.name} (${d.phone})'
                                      : d.name,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDriverId = val;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Date Selection
                      const Text('بەرواری گەشت *', style: AppTextStyles.bodyBold),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(AppRadius.input),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(_selectedDate),
                                style: AppTextStyles.bodyMedium,
                              ),
                              const Icon(Icons.calendar_today_outlined, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Notes
                      const Text('تێبینییەکان (ئارەزوومەندانە)', style: AppTextStyles.bodyBold),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'تێبینی بۆ شۆفێر یان ڕێگای گەیاندن...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.input),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Ready Orders Selection
                      readyOrdersAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Text(
                          'کێشە لە وەرگرتنی پسوڵە ئامادەکراوەکان: $err',
                          style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                        ),
                        data: (orders) {
                          if (orders.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey),
                                  SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'هیچ پسوڵەیەک لە دۆخی ئامادەکراو (READY) بەردەست نییە بۆ ناردن.',
                                    style: AppTextStyles.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          final isAllSelected = _selectedOrderIds.length == orders.length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'پسوڵە ئامادەکراوەکان (${_selectedOrderIds.length} لە ${orders.length} هەڵبژێردراون)',
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (isAllSelected) {
                                          _selectedOrderIds.clear();
                                        } else {
                                          _selectedOrderIds.clear();
                                          for (final o in orders) {
                                            if (o.id != null) {
                                              _selectedOrderIds.add(o.id!);
                                            }
                                          }
                                        }
                                      });
                                    },
                                    child: Text(
                                      isAllSelected ? 'سڕینەوەی هەمووی' : 'هەڵبژاردنی هەمووی',
                                      style: AppTextStyles.caption.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: orders.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  final orderId = order.id ?? 0;
                                  final isSelected = _selectedOrderIds.contains(orderId);

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.dividerColor,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(AppRadius.input),
                                      color: isSelected
                                          ? theme.colorScheme.primary.withOpacity(0.04)
                                          : null,
                                    ),
                                    child: CheckboxListTile(
                                      value: isSelected,
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            order.orderNumber,
                                            style: AppTextStyles.bodyBold,
                                          ),
                                          Text(
                                            Formatters.currency(order.totalAmount),
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        order.customer?.name ?? 'کڕیاری نەناسراو',
                                        style: AppTextStyles.caption,
                                      ),
                                      onChanged: (bool? checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedOrderIds.add(orderId);
                                          } else {
                                            _selectedOrderIds.remove(orderId);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('پاشگەزبوونەوە'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    text: _isSubmitting ? 'خەریکی دروستکردن...' : 'دروستکردنی گەشت',
                    isLoading: _isSubmitting,
                    onPressed: (_selectedDriverId == null || _selectedOrderIds.isEmpty || _isSubmitting)
                        ? null
                        : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
