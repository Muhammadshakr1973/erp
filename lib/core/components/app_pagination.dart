import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon_button.dart';

class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final bool isLoading;

  const AppPagination({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final canPrev = currentPage > 1 && !isLoading;
    final canNext = currentPage < totalPages && !isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Next Button (in RTL, moving forward in list corresponds to "Next", which points to left in RTL, but we can standardise Arrow Forward/Back)
          AppIconButton(
            icon: Symbols.chevron_right, // RTL makes right point left, so let's use standard direction indicators
            onPressed: canPrev ? () => onPageChanged(currentPage - 1) : null,
            backgroundColor: canPrev
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            iconColor: canPrev ? theme.colorScheme.primary : Colors.grey.withOpacity(0.5),
            size: 38,
            isCircle: true,
          ),
          
          // Page Indicator Info
          Row(
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'پەڕەی $currentPage لە $totalPages',
                style: AppTextStyles.bodyBold.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          // Previous Button
          AppIconButton(
            icon: Symbols.chevron_left,
            onPressed: canNext ? () => onPageChanged(currentPage + 1) : null,
            backgroundColor: canNext
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            iconColor: canNext ? theme.colorScheme.primary : Colors.grey.withOpacity(0.5),
            size: 38,
            isCircle: true,
          ),
        ],
      ),
    );
  }
}
