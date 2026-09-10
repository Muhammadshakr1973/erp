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
import '../../auth/providers/auth_provider.dart';
import '../../shared/views/customer_selection_dialog.dart';
import '../../shared/models/customer.dart';
import '../../shared/views/customer_form_dialog.dart';
import '../../shared/providers/customer_provider.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import 'salesman_my_commissions_screen.dart';

class SalesmanDashboardScreen extends ConsumerWidget {
  const SalesmanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncService = ref.read(syncServiceProvider);

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
            _buildSyncStatusBanner(context, syncStatus, syncService),
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
                  () async {
                    final selectedCustomer = await CustomerSelectionDialog.show(
                      context,
                    );
                    if (selectedCustomer != null && context.mounted) {
                      context.push(
                        '/salesman/create-order',
                        extra: {'preselectedCustomerId': selectedCustomer.id},
                      );
                    }
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
                TextButton(onPressed: () {}, child: const Text('هەمووی')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                return AppCard(
                  onTap: () {
                    context.push('/order/100${index + 1}');
                  },
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: AppIcons.order,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مارکێتی ئەحمەد',
                              style: AppTextStyles.bodyBold,
                            ),
                            Text(
                              'پسوڵەی #100${index + 1}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('125,000 د.ع', style: AppTextStyles.price),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: index == 0 ? 'DRAFT' : 'CONFIRMED',
                            type: index == 0
                                ? StatusBadgeType.warning
                                : StatusBadgeType.success,
                          ),
                        ],
                      ),
                    ],
                  ),
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
        message = 'هەڵەیەک لە سینککردندا هەیە. بۆ هەوڵدانەوە کلیک بکە.';
        break;
    }

    return InkWell(
      onTap: () {
        syncService.syncPendingOperations();
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
              Icon(Icons.refresh, color: textColor, size: 20),
          ],
        ),
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
}
