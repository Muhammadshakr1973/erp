import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerReconciliationDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerReconciliationDialog({super.key, required this.customer});

  @override
  ConsumerState<CustomerReconciliationDialog> createState() =>
      _CustomerReconciliationDialogState();
}

class _CustomerReconciliationDialogState
    extends ConsumerState<CustomerReconciliationDialog> {
  bool _isFixing = false;

  @override
  Widget build(BuildContext context) {
    final reconciliationAsync =
        ref.watch(customerReconciliationProvider(widget.customer.id));
    final currentUser = ref.watch(authProvider).user;
    final canFix = currentUser?.hasPermission('users.manage') ?? false;

    return AlertDialog(
      title: const Text('هاوتاکردنەوەی بالانس', style: AppTextStyles.h2),
      content: SizedBox(
        width: double.maxFinite,
        child: reconciliationAsync.when(
          loading: () => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('خەریکی وەرگرتنی ڕاپۆرتە...', style: AppTextStyles.bodyMedium),
            ],
          ),
          error: (e, st) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('هەڵە ڕوویدا: $e', textAlign: TextAlign.center),
            ],
          ),
          data: (report) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    color: report.isConsistent
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.danger.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        Icon(
                          report.isConsistent
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          color: report.isConsistent
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            report.isConsistent
                                ? 'بالانسی کڕیار هاوتایە و کێشەی نییە'
                                : 'جیاوازی لە بالانسی کڕیاردا دۆزرایەوە!',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: report.isConsistent
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildBalanceInfo('بالانسی تۆمارکراو', report.storedBalance),
                  const Divider(),
                  _buildBalanceInfo(
                    'بالانسی هەژمارکراوە (Ledger)',
                    report.recalculatedBalance,
                  ),
                  if (!report.isConsistent) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('بڕی جیاوازی', style: AppTextStyles.bodyBold),
                        Text(
                          Formatters.currency(report.discrepancyAmount),
                          style: AppTextStyles.price.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (report.discrepancies.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text('لێکترازاوەکان:', style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppSpacing.xs),
                    ...report.discrepancies.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $d',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.danger,
                              fontSize: 11,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('داخستن'),
        ),
        reconciliationAsync.maybeWhen(
          data: (report) {
            if (!report.isConsistent && canFix) {
              return AppButton(
                text: 'ڕاستکردنەوە',
                isLoading: _isFixing,
                onPressed: () => _confirmFix(context, report),
              );
            }
            return const SizedBox.shrink();
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBalanceInfo(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            Formatters.currency(amount),
            style: AppTextStyles.bodyBold,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFix(
    BuildContext context,
    CustomerReconciliationModel report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ئاگاداری ڕاستکردنەوە', style: AppTextStyles.h3),
        content: Text(
          'دڵنیایت لە ڕاستکردنەوەی بالانسی کڕیار بۆ بڕی ${Formatters.currency(report.recalculatedBalance)}؟\n\nئەم کردارە تەنها بالانسی ئێستای کڕیارەکە ڕاست دەکاتەوە بۆ ئەوەی هاوتای مێژووی جوڵەکانی (Ledger) بێت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بەڵێ، ڕاستیبکەرەوە'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isFixing = true);
      try {
        await ref
            .read(customerActionsProvider)
            .fixCustomerBalance(widget.customer.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('بالانسی کڕیار بە سەرکەوتوویی ڕاستکرایەوە'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('هەڵە لە ڕاستکردنەوە: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isFixing = false);
      }
    }
  }
}
