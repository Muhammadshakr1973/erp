import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/utils/formatters.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';

class SupplierReconciliationDialog extends ConsumerStatefulWidget {
  final SupplierModel supplier;

  const SupplierReconciliationDialog({super.key, required this.supplier});

  @override
  ConsumerState<SupplierReconciliationDialog> createState() =>
      _SupplierReconciliationDialogState();
}

class _SupplierReconciliationDialogState
    extends ConsumerState<SupplierReconciliationDialog> {
  bool _isFixing = false;

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Future<void> _handleFix() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ڕاستکردنەوەی باڵانس', style: AppTextStyles.h3),
        content: const Text(
          'ئایا دڵنیایت لە ڕاستکردنەوەی باڵانسی ئەم کۆمپانیایە؟ ئەم کردارە باڵانسی ئێستا دەگۆڕێت بۆ ئەو بڕەی کە لە مێژووی جوڵەکانەوە (Ledger) هەژمارکراوە.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('دڵنیام، ڕاستیبکەرەوە'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isFixing = true);
      try {
        await ref
            .read(supplierActionsProvider)
            .fixSupplierBalance(widget.supplier.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('باڵانس بە سەرکەوتوویی ڕاستکرایەوە'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('هەڵە ڕوویدا: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isFixing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reconciliationAsync =
        ref.watch(supplierReconciliationProvider(widget.supplier.id));

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لێکترازانی دارایی کۆمپانیا', style: AppTextStyles.h2),
          Text(
            widget.supplier.name,
            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: reconciliationAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => SizedBox(
            height: 200,
            child: Center(child: Text('هەڵە لە وەرگرتنی ڕاپۆرت: $e')),
          ),
          data: (report) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(report.isConsistent),
                  const SizedBox(height: AppSpacing.md),
                  _buildComparisonTable(report),
                  if (report.discrepancies.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text('لیستی لێکترازانەکان:', style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppSpacing.xs),
                    ...report.discrepancies.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 14,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!report.isConsistent) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'ئاگاداری: باڵانسی پاشەکەوتکراو لەگەڵ کۆی جوڵەکان یەکناگرێتەوە. پێشنیار دەکرێت باڵانسەکە ڕاست بکرێتەوە.',
                        style: AppTextStyles.caption,
                      ),
                    ),
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
          data: (report) => !report.isConsistent
              ? AppButton(
                  text: 'ڕاستکردنەوەی باڵانس',
                  onPressed: _handleFix,
                  isLoading: _isFixing,
                )
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStatusCard(bool isConsistent) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isConsistent
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConsistent
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConsistent ? Icons.check_circle : Icons.warning,
            color: isConsistent ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isConsistent ? 'دارایی ڕێکە و هیچ کێشەیەک نییە' : 'لێکترازانی دارایی دۆزرایەوە',
              style: AppTextStyles.bodyBold.copyWith(
                color: isConsistent ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(report) {
    return AppCard(
      child: Column(
        children: [
          _buildComparisonRow(
            'باڵانسی پاشەکەوتکراو',
            _formatCurrency(report.storedBalance),
          ),
          const Divider(),
          _buildComparisonRow(
            'باڵانسی هەژمارکراو',
            _formatCurrency(report.recalculatedBalance),
            highlight: true,
          ),
          const Divider(),
          _buildComparisonRow(
            'جیاوازی',
            _formatCurrency(
              (report.storedBalance - report.recalculatedBalance).abs(),
            ),
            isDifference: true,
            hasDifference: !report.isConsistent,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    String value, {
    bool highlight = false,
    bool isDifference = false,
    bool hasDifference = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(
            value,
            style: highlight || (isDifference && hasDifference)
                ? AppTextStyles.bodyBold.copyWith(
                    color: isDifference && hasDifference
                        ? AppColors.danger
                        : AppColors.primary,
                  )
                : AppTextStyles.bodyMedium,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
