import 'package:flutter/material.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class PackOrderScreen extends StatefulWidget {
  final String orderId;

  const PackOrderScreen({super.key, required this.orderId});

  @override
  State<PackOrderScreen> createState() => _PackOrderScreenState();
}

class _PackOrderScreenState extends State<PackOrderScreen> {
  final List<bool> _packedItems = List.generate(5, (index) => false);

  bool get _isAllPacked => _packedItems.every((isPacked) => isPacked);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('پاکەتکردنی پسوڵەی #${widget.orderId}', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            onPressed: () {
              // Barcode scanner
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOrderSummary(theme),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: _packedItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final isPacked = _packedItems[index];
                return AppCard(
                  child: CheckboxListTile(
                    value: isPacked,
                    onChanged: (value) {
                      setState(() {
                        _packedItems[index] = value ?? false;
                      });
                    },
                    title: Text(
                      'شامپۆی سەر، قەبارەی گەورە ${index + 1}',
                      style: AppTextStyles.bodyBold.copyWith(
                        decoration: isPacked ? TextDecoration.lineThrough : null,
                        color: isPacked ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      '2 کارتۆن',
                      style: AppTextStyles.caption.copyWith(
                        color: isPacked ? Colors.grey : theme.colorScheme.primary,
                      ),
                    ),
                    activeColor: AppColors.success,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
          _buildBottomAction(theme),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کڕیار: مارکێتی ئەحمەد', style: AppTextStyles.bodyBold),
              Text('بەروار: 2026-08-23', style: AppTextStyles.caption),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isAllPacked ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_packedItems.where((e) => e).length} / ${_packedItems.length} تەواوبووە',
              style: AppTextStyles.bodyBold.copyWith(
                color: _isAllPacked ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: AppButton(
          text: 'پسوڵەکە ئامادەیە (Ready)',
          onPressed: _isAllPacked ? () {} : null,
          size: AppButtonSize.lg,
        ),
      ),
    );
  }
}
