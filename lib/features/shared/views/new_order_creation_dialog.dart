import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';
import '../providers/warehouse_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import 'customer_selection_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class NewOrderCreationDialog extends ConsumerStatefulWidget {
  const NewOrderCreationDialog({super.key});

  static Future<OrderModel?> show(BuildContext context) async {
    final createdOrder = await showDialog<OrderModel>(
      context: context,
      builder: (context) => const NewOrderCreationDialog(),
    );
    if (createdOrder != null && context.mounted) {
      context.push('/salesman/create-order', extra: createdOrder);
    }
    return createdOrder;
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
    final currentUser = ref.watch(authProvider).user;
    final isSalesman = currentUser?.isSalesman ?? false;

    // Automatically select the warehouse
    warehousesAsync.whenData((warehouses) {
      if (!_initialized && warehouses.isNotEmpty) {
        if (isSalesman) {
          final assignedWh = warehouses.firstWhere(
            (w) => w.id == currentUser?.warehouseId,
            orElse: () => warehouses.first,
          );
          _selectedWarehouse = assignedWh;
        } else {
          final mainWh = warehouses.firstWhere((w) => w.isMain, orElse: () => warehouses.first);
          _selectedWarehouse = mainWh;
        }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('کڕیار', style: AppTextStyles.bodyBold),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCustomer = Customer.temporary;
                    });
                  },
                  icon: const Icon(Icons.flash_on, size: 16, color: Colors.orange),
                  label: const Text(
                    'کڕیاری کاتی',
                    style: TextStyle(
                      fontFamily: 'Rudaw',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
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
                    Icon(AppIcons.customer, color: Theme.of(context).colorScheme.primary),
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
            if (!isSalesman) ...[
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
            ],

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
                        'discount_type': 'FIXED',
                        'discount_percent': 0.0,
                        'discount_amount': 0.0,
                        'shared_key': 'order_${DateTime.now().microsecondsSinceEpoch}',
                        'version': 1,
                        'notes': null,
                        'items': [],
                      };

                      try {
                        final createdOrder = await ref.read(orderActionsProvider).createOrder(payload);
                        if (context.mounted) {
                          AppSnackbar.show(
                            context,
                            message: 'پسوڵەکە بە سەرکەوتوویی دروستکرا',
                            type: SnackbarType.success,
                          );
                          Navigator.of(context).pop(createdOrder);
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
