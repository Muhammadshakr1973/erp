import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_dropdown.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/providers/orders_provider.dart';
import '../../shared/providers/customer_provider.dart';
import 'providers/user_provider.dart';

class AdminOrderFilterDialog extends ConsumerStatefulWidget {
  const AdminOrderFilterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const AdminOrderFilterDialog(),
    );
  }

  @override
  ConsumerState<AdminOrderFilterDialog> createState() =>
      _AdminOrderFilterDialogState();
}

class _AdminOrderFilterDialogState
    extends ConsumerState<AdminOrderFilterDialog> {
  late TextEditingController _searchController;
  int? _selectedCustomerId;
  int? _selectedSalesmanId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(adminOrderFilterProvider);
    _searchController = TextEditingController(text: currentState.searchQuery);
    _selectedCustomerId = currentState.customerId;
    _selectedSalesmanId = currentState.salesmanId;
    _startDate = currentState.startDate;
    _endDate = currentState.endDate;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCustomerId = null;
      _selectedSalesmanId = null;
      _startDate = null;
      _endDate = null;
    });
    ref.read(adminOrderFilterProvider.notifier).state =
        const AdminOrderFilterState();
    Navigator.of(context).pop();
  }

  void _applyFilters() {
    ref.read(adminOrderFilterProvider.notifier).state = AdminOrderFilterState(
      searchQuery: _searchController.text.trim(),
      customerId: _selectedCustomerId,
      salesmanId: _selectedSalesmanId,
      startDate: _startDate,
      endDate: _endDate,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customersAsync = ref.watch(customerListProvider);
    final salesmenAsync = ref.watch(salesmenListProvider);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
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
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.filter,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text(
                        'فلتەرکردنی پسوڵەکان',
                        style: AppTextStyles.h2,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'داخستن',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),

              // Search query field
              AppTextField(
                controller: _searchController,
                labelText: 'گەڕان',
                hintText: 'ژمارەی پسوڵە، ناوی کڕیار، یان ناوی مەندوب...',
                prefixIcon: Icons.search,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),

              // Salesman Dropdown
              salesmenAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Text(
                  'هەڵە لە هێنانی مەندوبەکان: $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
                data: (salesmen) {
                  return AppDropdownFormField<int?>(
                    value: _selectedSalesmanId,
                    labelText: 'مەندوب / فرۆشیار',
                    prefixIcon: AppIcons.customers,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('هەموو مەندوبەکان'),
                      ),
                      ...salesmen.map(
                        (sm) => DropdownMenuItem<int?>(
                          value: sm.id,
                          child: Text(sm.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSalesmanId = val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Customer Dropdown
              customersAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Text(
                  'هەڵە لە هێنانی کڕیاران: $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
                data: (customers) {
                  return AppDropdownFormField<int?>(
                    value: _selectedCustomerId,
                    labelText: 'کڕیار',
                    prefixIcon: AppIcons.customers,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('هەموو کڕیارەکان'),
                      ),
                      ...customers.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerId = val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Date Range Selection
              Text(
                'ماوەی بەروار',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      borderRadius: AppRadius.radiusMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: AppRadius.radiusMd,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _startDate != null
                                    ? Formatters.date(_startDate!)
                                    : 'لە بەرواری...',
                                style: _startDate != null
                                    ? AppTextStyles.bodyMedium
                                    : AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      borderRadius: AppRadius.radiusMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: AppRadius.radiusMd,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _endDate != null
                                    ? Formatters.date(_endDate!)
                                    : 'تا بەرواری...',
                                style: _endDate != null
                                    ? AppTextStyles.bodyMedium
                                    : AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'سڕینەوەی بەروار',
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'پاککردنەوە',
                      type: AppButtonType.outline,
                      onPressed: _clearFilters,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      text: 'جێبەجێکردن',
                      type: AppButtonType.primary,
                      onPressed: _applyFilters,
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
