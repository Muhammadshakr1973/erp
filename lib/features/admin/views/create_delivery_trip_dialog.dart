import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/providers/driver_providers.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && (user.isDriver || user.role.toLowerCase() == 'driver')) {
        setState(() {
          _selectedDriverId = user.id;
        });
      }
    });
  }

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
    final currentUser = ref.watch(authProvider).user;
    final isDriver = currentUser != null && (currentUser.isDriver || currentUser.role.toLowerCase() == 'driver');
    final driversAsync = ref.watch(activeDriversProvider);
    final readyOrdersAsync = ref.watch(readyOrdersForDeliveryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isDriver ? 'دروستکردنی گەشتی نوێ' : 'ناردنی گەشتی نوێ',
                      style: AppTextStyles.h2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver Selection
                      const Text('شۆفێر *', style: AppTextStyles.bodyBold),
                      const SizedBox(height: AppSpacing.xs),
                      if (isDriver)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.profile, color: theme.colorScheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                currentUser?.name ?? '',
                                style: AppTextStyles.bodyBold,
                              ),
                            ],
                          ),
                        )
                      else
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
                                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: const Text(
                                  'هیچ شۆفێرێکی چالاک نەدۆزرایەوە لە سیستەمدا.',
                                  style: AppTextStyles.caption,
                                ),
                              );
                            }

                            return DropdownButtonFormField<int>(
                              initialValue: _selectedDriverId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(AppRadius.md),
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
                            borderRadius: BorderRadius.circular(AppRadius.md),
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
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                  Expanded(
                                    child: Text(
                                      'پسوڵە ئامادەکراوەکان (${_selectedOrderIds.length} لە ${orders.length} هەڵبژێردراون)',
                                      style: AppTextStyles.bodyBold,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (isAllSelected) {
                                          _selectedOrderIds.clear();
                                        } else {
                                          _selectedOrderIds.clear();
                                          for (final o in orders) {
                                            _selectedOrderIds.add(o.id);
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
                                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  final orderId = order.id;
                                  final isSelected = _selectedOrderIds.contains(orderId);

                                  final routeText = (order.customerRouteName != null && order.customerRouteName.trim().isNotEmpty)
                                      ? order.customerRouteName.trim()
                                      : 'دیاری نەکراوە';
                                  final noteText = (order.notes != null && order.notes!.trim().isNotEmpty)
                                      ? order.notes!.trim()
                                      : 'نییە';

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedOrderIds.remove(orderId);
                                          } else {
                                            _selectedOrderIds.add(orderId);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(AppRadius.lg),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary.withValues(alpha: 0.06)
                                              : theme.colorScheme.surface,
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.dividerColor.withValues(alpha: 0.6),
                                            width: isSelected ? 1.8 : 1.0,
                                          ),
                                          borderRadius: BorderRadius.circular(AppRadius.lg),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(AppSpacing.md),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Checkbox
                                              SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  activeColor: theme.colorScheme.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
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
                                              ),
                                              const SizedBox(width: AppSpacing.sm),

                                              // Details: Customer Name, Route, Notes ONLY
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Customer Name
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.person_outline_rounded,
                                                          size: 18,
                                                          color: theme.colorScheme.primary,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'ناوی کڕیار: ${order.customerName}',
                                                            style: AppTextStyles.bodyBold.copyWith(
                                                              fontSize: 14,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),

                                                    // Route Name
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.alt_route_rounded,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'ڕاوت: $routeText',
                                                            style: AppTextStyles.bodyMedium.copyWith(
                                                              color: theme.colorScheme.onSurfaceVariant,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),

                                                    // Notes
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(
                                                          Icons.sticky_note_2_outlined,
                                                          size: 16,
                                                          color: noteText != 'نییە'
                                                              ? AppColors.warning
                                                              : Colors.grey,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'تێبینی: $noteText',
                                                            style: AppTextStyles.caption.copyWith(
                                                              color: noteText != 'نییە'
                                                                  ? theme.colorScheme.onSurface
                                                                  : theme.colorScheme.onSurfaceVariant,
                                                              fontWeight: noteText != 'نییە'
                                                                  ? FontWeight.w600
                                                                  : FontWeight.normal,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
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
              const SizedBox(height: AppSpacing.xs),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('پاشگەزبوونەوە'),
                        ),
                        AppButton(
                          text: _isSubmitting ? 'خەریکی دروستکردن...' : 'دروستکردنی گەشت',
                          isLoading: _isSubmitting,
                          onPressed: (_selectedDriverId == null || _selectedOrderIds.isEmpty || _isSubmitting)
                              ? null
                              : _submit,
                        ),
                      ],
                    ),
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
