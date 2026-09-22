import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_icon_button.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/views/customer_selection_dialog.dart';
import '../../shared/views/new_order_creation_dialog.dart';
import '../../shared/models/customer.dart';
import '../../shared/views/customer_form_dialog.dart';
import '../../shared/providers/customer_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import 'salesman_my_commissions_screen.dart';
import 'salesman_main_screen.dart';

class SalesmanDashboardScreen extends ConsumerWidget {
  const SalesmanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncService = ref.read(syncServiceProvider);
    final ordersAsync = ref.watch(ordersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سڵاو، ${user?.name ?? 'مەندوب'}', style: AppTextStyles.h2),
            Text(
              'گەڕەکی ئەمڕۆ: بەختیاری',
              style: AppTextStyles.caption.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notifications),
            onPressed: () {
              context.push('/notifications');
            },
          ),
          IconButton(
            icon: Icon(
              Icons.sync,
              color: syncStatus == SyncStatus.syncing
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: () {
              ref.read(syncServiceProvider).syncPendingOperations();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('دەستکرا بە سینککردنی داتاکان...'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline Status Banner
            _buildSyncStatusBanner(context, syncStatus, syncService, ref),
            const SizedBox(height: AppSpacing.sectionGap),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.order, color: AppColors.info),
                        const SizedBox(height: 8),
                        Text('فرۆشتنی ئەمڕۆ', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('450,000 د.ع', style: AppTextStyles.h2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.customer, color: AppColors.purple),
                        const SizedBox(height: 8),
                        Text('سەردانەکان', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('12 / 24', style: AppTextStyles.h2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Quick Actions
            Text('کردارە خێراکان', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.5,
              children: [
                _buildActionCard(
                  context,
                  'پسوڵەی نوێ',
                  AppIcons.newOrder,
                  () {
                    NewOrderCreationDialog.show(context);
                  },
                ),
                _buildActionCard(context, 'کۆمسیۆنەکانم', Icons.percent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesmanMyCommissionsScreen(),
                    ),
                  );
                }),
                _buildActionCard(
                  context,
                  'وەرگرتنی پارە',
                  AppIcons.customerDebt,
                  () async {
                    final selectedCustomer = await CustomerSelectionDialog.show(
                      context,
                    );
                    if (selectedCustomer != null && context.mounted) {
                      _showPaymentDialog(context, ref, selectedCustomer);
                    }
                  },
                ),
                _buildActionCard(context, 'داواکاری کاڵا', AppIcons.add, () {}),
                _buildActionCard(
                  context,
                  'کڕیاری نوێ',
                  AppIcons.customers,
                  () {
                    showDialog(
                      context: context,
                      builder: (context) => const CustomerFormDialog(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('دوایین پسوڵەکان', style: AppTextStyles.h2),
                TextButton(
                  onPressed: () {
                    ref.read(salesmanTabIndexProvider.notifier).state = 2; // Swaps to the orders tab
                  },
                  child: const Text('هەمووی'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ordersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'هەڵە لە بارکردنی پسوڵەکاندا هەیە: ${Formatters.cleanError(err)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                  ),
                ),
              ),
              data: (orders) {
                // Fetch the salesman's orders only (although server already filters by logged-in salesman, we keep a client-side filter for safety)
                final salesmanOrders = orders
                    .where((o) => o.salesmanId == user?.id)
                    .toList();

                if (salesmanOrders.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'هیچ پسوڵەیەک نییە بۆ نیشاندان',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  );
                }

                // Take top 3 recent orders
                final recentOrders = salesmanOrders.take(3).toList();

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentOrders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = recentOrders[index];
                    final customerName = order.customer != null
                        ? order.customer['name']
                        : 'نەناسراو';

                    String statusLabel = 'داڕشتن (Draft)';
                    StatusBadgeType statusType = StatusBadgeType.warning;

                    final normalizedStatus = order.status.toUpperCase();
                    switch (normalizedStatus) {
                      case 'DELIVERED':
                        statusLabel = 'گەیشتووە';
                        statusType = StatusBadgeType.success;
                        break;
                      case 'CONFIRMED':
                        statusLabel = 'پشتڕاستکراوەتەوە';
                        statusType = StatusBadgeType.info;
                        break;
                      case 'PACKING':
                        statusLabel = 'لە پاکەتکردندایە';
                        statusType = StatusBadgeType.info;
                        break;
                      case 'READY':
                        statusLabel = 'ئامادەیە بۆ ناردن';
                        statusType = StatusBadgeType.info;
                        break;
                      case 'IN_DELIVERY':
                        statusLabel = 'لە ڕێگەی گەیاندندایە';
                        statusType = StatusBadgeType.warning;
                        break;
                      case 'CANCELLED':
                        statusLabel = 'هەڵوەشاوەتەوە';
                        statusType = StatusBadgeType.danger;
                        break;
                      case 'DRAFT':
                      default:
                        statusLabel = 'داڕشتن (Draft)';
                        statusType = StatusBadgeType.warning;
                        break;
                    }

                    return AppCard(
                      onTap: () {
                        if (order.status == 'PACKING' || order.status == 'DRAFT') {
                          context.push('/salesman/create-order', extra: order);
                        } else {
                          context.push('/order/${order.id}');
                        }
                      },
                      onLongPress: () {
                        _showDeleteConfirmationDialog(context, ref, order, customerName);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                AppIcons.order,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: AppTextStyles.bodyBold,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'پسوڵەی #${order.orderNumber}',
                                        style: AppTextStyles.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (order.pendingSync) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.sync,
                                        size: 12,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${Formatters.currency(order.totalAmount)}',
                                style: AppTextStyles.price,
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(label: statusLabel, type: statusType),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusBanner(
    BuildContext context,
    SyncStatus status,
    SyncService syncService,
    WidgetRef ref,
  ) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String message;

    switch (status) {
      case SyncStatus.synced:
        bgColor = AppColors.success.withValues(alpha: 0.1);
        borderColor = AppColors.success.withValues(alpha: 0.3);
        textColor = AppColors.success;
        icon = Icons.cloud_done;
        message = 'داتاکان بەسەرکەوتوویی سینک کراون (ئۆفلاین ئامادەیە)';
        break;
      case SyncStatus.syncing:
        bgColor = AppColors.info.withValues(alpha: 0.1);
        borderColor = AppColors.info.withValues(alpha: 0.3);
        textColor = AppColors.info;
        icon = Icons.sync;
        message = 'داتاکان لە پڕۆسەی سینککردندان، تکایە چاوەڕێ بکە...';
        break;
      case SyncStatus.error:
        bgColor = AppColors.danger.withValues(alpha: 0.1);
        borderColor = AppColors.danger.withValues(alpha: 0.3);
        textColor = AppColors.danger;
        icon = Icons.error_outline;
        message = 'هەڵەیەک لە سینککردندا هەیە. بۆ چارەسەرکردن و زانیاری زیاتر لێرە کلیک بکە.';
        break;
    }

    return InkWell(
      onTap: () {
        if (status == SyncStatus.error) {
          _showSyncQueueDialog(context, ref);
        } else {
          syncService.syncPendingOperations();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
            if (status == SyncStatus.error)
              Icon(Icons.arrow_forward_ios, color: textColor, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSyncQueueDialog(BuildContext context, WidgetRef ref) {
    final syncService = ref.read(syncServiceProvider);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) {
        final failedEntries = syncService.box.values
            .where((e) => e.status == 'FAILED')
            .toList();

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sync_problem, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'کێشەکانی هاوشێوەکردن',
                  style: AppTextStyles.h2,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: failedEntries.isEmpty
                ? const Text(
                    'هیچ هەڵەیەکی چالاک نییە لە سیستەمەکەدا.',
                    textDirection: TextDirection.rtl,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: failedEntries.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = failedEntries[index];
                      
                      String opLabel = entry.operationType;
                      switch (entry.operationType) {
                        case 'CREATE_ORDER':
                          opLabel = 'دروستکردنی پسوڵە';
                          break;
                        case 'UPDATE_ORDER':
                          opLabel = 'نوێکردنەوەی پسوڵە';
                          break;
                        case 'CREATE_PAYMENT':
                          opLabel = 'تۆمارکردنی پارەدان';
                          break;
                        case 'CREATE_CUSTOMER':
                          opLabel = 'تۆمارکردنی کڕیاری نوێ';
                          break;
                        case 'UPDATE_CUSTOMER':
                          opLabel = 'نوێکردنەوەی زانیاری کڕیار';
                          break;
                      }

                      String errorMsg = entry.errorInformation ?? 'هەڵەیەکی نەناسراو ڕوویداوە';
                      if (errorMsg.startsWith('{') && errorMsg.endsWith('}')) {
                        try {
                          final parsed = jsonDecode(errorMsg);
                          if (parsed is Map && parsed['message'] != null) {
                            errorMsg = parsed['message'];
                          }
                        } catch (_) {}
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: TextDirection.rtl,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text(
                                opLabel,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              Text(
                                '${entry.retryCount} هەوڵدان',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'هۆکاری هەڵە: $errorMsg',
                            style: AppTextStyles.caption.copyWith(
                              color: theme.colorScheme.error.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await syncService.clearFailedOperations();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ڕیزی هەڵەکان بە سەرکەوتوویی پاککرایەوە')),
                  );
                }
              },
              child: Text(
                'پاککردنەوەی هەڵەکان',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton(
              onPressed: () {
                syncService.syncPendingOperations();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('دەستکرا بە هەوڵدانەوەی هاوشێوەکردن...')),
                );
              },
              child: const Text('هەوڵدانەوە'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isPaying = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تۆمارکردنی پارەدان', style: AppTextStyles.h2),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کڕیار: ${customer.name}',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: amountController,
                    labelText: 'بڕی پارە (د.ع)',
                    prefixIcon: Icons.money,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'تکایە بڕی پارە بنووسە';
                      }
                      if (int.tryParse(val) == null) {
                        return 'بڕی پارە نادروستە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: notesController,
                    labelText: 'تێبینی',
                    prefixIcon: Icons.note,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'پاشگەزبوونەوە',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              AppButton(
                text: 'تۆمارکردن',
                isLoading: isPaying,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setStateDialog(() => isPaying = true);
                    try {
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.enqueueOperation(
                        entityId: 'local_payment_${DateTime.now().microsecondsSinceEpoch}',
                        operationType: 'CREATE_PAYMENT',
                        payload: {
                          'customer_id': customer.id,
                          'amount': int.parse(amountController.text),
                          'notes': notesController.text,
                          'payment_method': 'CASH',
                        },
                      );

                      ref.invalidate(customerListProvider);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'داواکاری پارەدانەکە بە سەرکەوتوویی خرایە ڕیزی سینکەوە',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('هەڵە ڕوویدا: $e'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    } finally {
                      setStateDialog(() => isPaying = false);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: AppRadius.radiusLg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
    String customerName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'سڕینەوەی پسوڵە',
            style: AppTextStyles.h2,
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            'ئایا دڵنیایت لە سڕینەوەی پسوڵەی #${order.orderNumber} بۆ کڕیار $customerName؟',
            style: AppTextStyles.bodyMedium,
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(orderActionsProvider).deleteOrder(order.id.toString());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('پسوڵەکە بە سەرکەوتوویی سڕایەوە یان خرایە ڕیزی سڕینەوەوە'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('هەڵە ڕوویدا لە سڕینەوە: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'سڕینەوە',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
