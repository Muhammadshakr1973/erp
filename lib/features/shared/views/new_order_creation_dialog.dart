import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';
import '../providers/warehouse_provider.dart';
import '../../orders/providers/orders_provider.dart';
import 'customer_selection_dialog.dart';

class NewOrderCreationDialog extends ConsumerStatefulWidget {
  const NewOrderCreationDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const NewOrderCreationDialog(),
    );
  }

  @override
  ConsumerState<NewOrderCreationDialog> createState() => _NewOrderCreationDialogState();
}

class _NewOrderCreationDialogState extends ConsumerState<NewOrderCreationDialog> {
  Customer? _selectedCustomer;
  WarehouseModel? _selectedWarehouse;
  bool _initialized = false;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehouseListProvider);

    // Automatically select the main warehouse once loaded
    warehousesAsync.whenData((warehouses) {
      if (!_initialized && warehouses.isNotEmpty) {
        final mainWh = warehouses.firstWhere((w) => w.isMain, orElse: () => warehouses.first);
        _selectedWarehouse = mainWh;
        _initialized = true;
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 420),
        width: double.maxFinite,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('پسوڵەی نوێ', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Customer Selector Button
            const Text('کڕیار', style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: () async {
                final customer = await CustomerSelectionDialog.show(context);
                if (customer != null) {
                  setState(() {
                    _selectedCustomer = customer;
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.customer, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _selectedCustomer != null ? _selectedCustomer!.name : 'دیاریکردنی کڕیار...',
                        style: _selectedCustomer != null ? AppTextStyles.bodyBold : AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Warehouse Dropdown
            const Text('کۆگا', style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            warehousesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('هەڵە لە بارکردنی کۆگاکان: $err', style: const TextStyle(color: AppColors.danger)),
              data: (warehouses) {
                if (warehouses.isEmpty) {
                  return const Text('هیچ کۆگایەک بەردەست نییە', style: TextStyle(color: AppColors.danger));
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<WarehouseModel>(
                      value: _selectedWarehouse,
                      isExpanded: true,
                      items: warehouses.map((wh) {
                        return DropdownMenuItem<WarehouseModel>(
                          value: wh,
                          child: Text(wh.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedWarehouse = val;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Submit Button
            AppButton(
              text: 'دروستکردنی پسوڵە',
              isLoading: _isCreating,
              onPressed: (_selectedCustomer != null && _selectedWarehouse != null && !_isCreating)
                  ? () async {
                      setState(() {
                        _isCreating = true;
                      });
                      final payload = {
                        'customer_id': _selectedCustomer!.id,
                        'warehouse_id': _selectedWarehouse!.id,
                        'status': 'PACKING',
                        'discount_type': 'PERCENT',
                        'discount_percent': 0.0,
                        'discount_amount': 0.0,
                        'shared_key': 'order_${DateTime.now().microsecondsSinceEpoch}',
                        'version': 1,
                        'notes': null,
                        'items': [],
                      };

                      try {
                        await ref.read(orderActionsProvider).createOrder(payload);
                        if (context.mounted) {
                          AppSnackbar.show(
                            context,
                            message: 'پسوڵەکە بە سەرکەوتوویی دروستکرا',
                            type: SnackbarType.success,
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.show(
                            context,
                            message: 'هەڵە لە دروستکردنی پسوڵە: $e',
                            type: SnackbarType.error,
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isCreating = false;
                          });
                        }
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
