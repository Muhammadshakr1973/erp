import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_dialog.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/suppliers_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/views/supplier_reconciliation_dialog.dart';
import 'supplier_form_dialog.dart';

class AdminSuppliersFullscreenDialog extends ConsumerStatefulWidget {
  const AdminSuppliersFullscreenDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog.fullscreen(
        child: AdminSuppliersFullscreenDialog(),
      ),
    );
  }

  @override
  ConsumerState<AdminSuppliersFullscreenDialog> createState() =>
      _AdminSuppliersFullscreenDialogState();
}

class _AdminSuppliersFullscreenDialogState
    extends ConsumerState<AdminSuppliersFullscreenDialog> {
  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Future<void> _showAddSupplierDialog(BuildContext context) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SupplierFormDialog(),
    );
    if (!mounted) return;

    if (result is SupplierModel || result == true) {
      ref.invalidate(suppliersListProvider);
    }
  }

  Future<void> _showEditSupplierDialog(
    BuildContext context,
    SupplierModel supplier,
  ) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    );
    if (success == true && mounted) {
      ref.invalidate(suppliersListProvider);
    }
  }

  void _deleteSupplier(SupplierModel supplier) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی کۆمپانیا',
      message: 'دڵنیایت لە سڕینەوەی کۆمپانیای "${supplier.name}"؟',
      confirmText: 'سڕینەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(supplierActionsProvider).deleteSupplier(supplier.id);
        if (!mounted) return;
        ref.invalidate(suppliersListProvider);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کۆمپانیا بە سەرکەوتوویی سڕایەوە',
            type: SnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'کێشە لە سڕینەوە: $e',
            type: SnackbarType.error,
          );
        }
      }
    }
  }


  Widget _buildSupplierCard(
    BuildContext context,
    SupplierModel supplier, {
    bool isMobileOrTablet = false,
  }) {
    final theme = Theme.of(context);
    final bool hasDebt = supplier.debt > 0;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final canReconcile = user?.hasPermission('users.manage') ?? false;

    final String phoneText =
        (supplier.phone != null && supplier.phone!.trim().isNotEmpty)
            ? supplier.phone!.trim()
            : 'مۆبایل نییە';
    final String addressText =
        (supplier.address != null && supplier.address!.trim().isNotEmpty)
            ? supplier.address!.trim()
            : 'ناونیشان نییە';

    final bool isMobileOrTabletView = isMobileOrTablet ||
        (MediaQuery.of(context).size.width < AppBreakpoints.desktopMin);

    return AppCard(
      onTap: () => _showEditSupplierDialog(context, supplier),
      onLongPress: () => _deleteSupplier(supplier),
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        supplier.name,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (canReconcile)
                      IconButton(
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                SupplierReconciliationDialog(
                                    supplier: supplier),
                          );
                        },
                        tooltip: 'لێکترازانی دارایی',
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'کەسی پەیوەندی: ${supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty ? supplier.contactPerson : '-'}',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isMobileOrTabletView) ...[
                  Text(
                    phoneText,
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    addressText,
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    '$phoneText • $addressText',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'کۆد: #${supplier.id}',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: hasDebt
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(supplier.debt),
                      style: AppTextStyles.bodyBold.copyWith(
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasDebt ? 'قەرزدار' : 'پاکە',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'KJino',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return PermissionGuard(
      permission: 'suppliers.manage',
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'کۆمپانیاکان',
            style: AppTextStyles.h2,
          ),
          actions: [
            IconButton(
              tooltip: 'داخستن',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(suppliersListProvider),
          child: suppliersAsync.when(
            data: (suppliers) {
              if (suppliers.isEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'هیچ کۆمپانیایەک نییە',
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: () => _showAddSupplierDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('زیادکردنی کۆمپانیا'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final screenWidth = MediaQuery.of(context).size.width;
              int crossAxisCount = 1;
              if (screenWidth >= 1024) {
                crossAxisCount = 3;
              } else if (screenWidth >= 600) {
                crossAxisCount = 2;
              }

              final bool isMobileOrTablet = screenWidth < AppBreakpoints.desktopMin;

              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                itemCount: suppliers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: isMobileOrTablet ? 124 : 82,
                ),
                itemBuilder: (context, index) => _buildSupplierCard(
                  context,
                  suppliers[index],
                  isMobileOrTablet: isMobileOrTablet,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Text(
                      'شکست لە هێنانی زانیارییەکان: $error',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
