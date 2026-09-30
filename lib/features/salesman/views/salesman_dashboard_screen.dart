import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/notification_badge_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/sync/sync_service.dart';
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
import '../providers/salesman_dashboard_provider.dart';
import 'salesman_my_commissions_screen.dart';
import 'salesman_main_screen.dart';

class SalesmanDashboardScreen extends ConsumerWidget {
  const SalesmanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersListProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncService = ref.watch(syncServiceProvider);
    final dashboardAsync = ref.watch(salesmanDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سڵاو، ${user?.name ?? 'مەندوب'}', style: AppTextStyles.h2),
            dashboardAsync.when(
              data: (dashboard) => Text(
                'گەڕەکی ئەمڕۆ: ${dashboard.routeName}',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              loading: () => Text(
                'باردەکرێت...',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              error: (_, _) => Text(
                'گەڕەکی ئەمڕۆ: گشتی',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBadgeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersListProvider);
          ref.invalidate(customerListProvider);
          ref.invalidate(salesmanDashboardProvider);
          await syncService.syncPendingOperations();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSyncStatusBanner(context, syncStatus, syncService),
              // Quick Stats & Chart
              dashboardAsync.when(
                data: (dashboard) => _buildSalesmanDashboardStats(context, dashboard),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'هەڵە لە بارکردنی ئامارەکاندا هەیە: ${Formatters.cleanError(err)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
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
                  // Fetch the salesman's orders only
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
                                  Text(
                                    'پسوڵەی #${order.orderNumber}',
                                    style: AppTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.currency(order.totalAmount),
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
      ),
    );
  }

  Widget _buildSyncStatusBanner(
    BuildContext context,
    SyncStatus status,
    SyncService syncService,
  ) {
    Color bgColor = AppColors.success.withValues(alpha: 0.15);
    Color borderColor = AppColors.success;
    IconData icon = Icons.cloud_done;
    Color textColor = AppColors.success;
    String message = 'هەموو داتاکان هاوکات کراون';

    switch (status) {
      case SyncStatus.syncing:
        bgColor = AppColors.info.withValues(alpha: 0.15);
        borderColor = AppColors.info;
        icon = Icons.sync;
        textColor = AppColors.info;
        message = 'داتاکان لە هاوکاتکردندان...';
        break;
      case SyncStatus.pending:
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        borderColor = AppColors.warning;
        icon = Icons.cloud_upload;
        textColor = AppColors.warning;
        message = 'کردەوەی پاشەکەوتکراو هەیە کە چاوەڕێی هاوکاتکردنن';
        break;
      case SyncStatus.error:
      case SyncStatus.failed:
        bgColor = AppColors.danger.withValues(alpha: 0.15);
        borderColor = AppColors.danger;
        icon = Icons.sync_problem;
        textColor = AppColors.danger;
        message = 'هەڵە لە هاوکاتکردنی هەندێک داتادا ڕوویدا';
        break;
      case SyncStatus.offline:
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        borderColor = AppColors.warning;
        icon = Icons.cloud_off;
        textColor = AppColors.warning;
        message = 'ئێستا ئۆفلاینیت؛ داتاکان لۆکاڵی پاشەکەوت دەکرێن';
        break;
      case SyncStatus.synced:
      case SyncStatus.idle:
      case SyncStatus.completed:
        bgColor = AppColors.success.withValues(alpha: 0.15);
        borderColor = AppColors.success;
        icon = Icons.cloud_done;
        textColor = AppColors.success;
        message = 'هەموو داتاکان هاوکات کراون';
        break;
    }

    if (status == SyncStatus.synced ||
        status == SyncStatus.idle ||
        status == SyncStatus.completed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (status != SyncStatus.syncing)
            IconButton(
              icon: Icon(Icons.refresh, color: textColor, size: 20),
              tooltip: 'هاوکاتکردنەوە',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                syncService.syncPendingOperations();
              },
            ),
        ],
      ),
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
                      await ref.read(customerActionsProvider).createPayment(
                        customerId: customer.id,
                        amount: int.parse(amountController.text.trim()),
                        paymentMethod: 'CASH',
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('پارەدانەکە بە سەرکەوتوویی تۆمارکرا'),
                            backgroundColor: AppColors.success,
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
                        content: Text('پسوڵەکە بە سەرکەوتوویی سڕایەوە'),
                        backgroundColor: AppColors.success,
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
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesmanDashboardStats(BuildContext context, SalesmanDashboardData dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ئامارەکانی چالاکی', style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.35,
          children: [
            // 1. فرۆشی هەفتە
            _buildStatCard(
              context,
              title: 'فرۆشی هەفتە',
              value: Formatters.currency(dashboard.last7DaysSales),
              icon: AppIcons.order,
              iconColor: AppColors.info,
            ),
            // 2. یەکەکانی هەفتە
            _buildStatCard(
              context,
              title: 'یەکەکانی هەفتە',
              value: '${dashboard.last7DaysUnits} یەکە',
              icon: Icons.analytics_rounded,
              iconColor: AppColors.purple,
            ),
            // 3. یەکەکانی مانگ
            _buildStatCard(
              context,
              title: 'یەکەکانی مانگ',
              value: '${dashboard.monthUnits} یەکە',
              icon: Icons.stars_rounded,
              iconColor: AppColors.warning,
            ),
            // 4. کڕیارە نوێکان
            _buildStatCard(
              context,
              title: 'کڕیارە نوێکان',
              value: 'هەفتە: ${dashboard.newCustomersWeek} | مانگ: ${dashboard.newCustomersMonth}',
              icon: AppIcons.customer,
              iconColor: AppColors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: iconColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
