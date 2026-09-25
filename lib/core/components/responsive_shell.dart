import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final List<int>? mobilePrimaryIndices;
  final Widget body;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.mobilePrimaryIndices,
    required this.body,
  });

  void _showMoreBottomSheet(
    BuildContext context,
    List<int> secondaryIndices,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'بەشەکانی تر',
                        style: AppTextStyles.h2.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'داخستن',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: secondaryIndices.map((index) {
                          final destination = destinations[index];
                          final isSelected = index == currentIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.primaryDark.withValues(alpha: 0.2)
                                      : AppColors.primaryLight)
                                  : (isDark
                                      ? AppColors.backgroundDark
                                      : AppColors.backgroundLight),
                              borderRadius: AppRadius.radiusLg,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                        ? AppColors.primaryDark
                                        : AppColors.primary)
                                    : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 2,
                              ),
                              leading: Theme(
                                data: theme.copyWith(
                                  iconTheme: IconThemeData(
                                    color: isSelected
                                        ? (isDark
                                            ? AppColors.primaryDark
                                            : AppColors.primary)
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                  ),
                                ),
                                child: isSelected
                                    ? (destination.selectedIcon ?? destination.icon)
                                    : destination.icon,
                              ),
                              title: Text(
                                destination.label,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.primaryDark
                                          : AppColors.primary)
                                      : (isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight),
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: isDark
                                        ? AppColors.primaryDark
                                        : AppColors.primary,
                                      size: 20,
                                    )
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.radiusLg,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                onDestinationSelected(index);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (AppBreakpoints.isMobile(width)) {
          if (mobilePrimaryIndices != null &&
              mobilePrimaryIndices!.isNotEmpty &&
              mobilePrimaryIndices!.length < destinations.length) {
            final primaryIndices = mobilePrimaryIndices!;
            final secondaryIndices = [
              for (int i = 0; i < destinations.length; i++)
                if (!primaryIndices.contains(i)) i
            ];

            final mobileDestinations = <NavigationDestination>[
              ...primaryIndices.map((i) => destinations[i]),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: 'تر',
              ),
            ];

            final activeSlot = primaryIndices.indexOf(currentIndex);
            final selectedIndex =
                activeSlot != -1 ? activeSlot : primaryIndices.length;

            return Scaffold(
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (slotIndex) {
                  if (slotIndex == primaryIndices.length) {
                    _showMoreBottomSheet(context, secondaryIndices);
                  } else {
                    onDestinationSelected(primaryIndices[slotIndex]);
                  }
                },
                destinations: mobileDestinations,
              ),
            );
          }

          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          );
        } else {
          // Both Tablet and Desktop use the same NavigationRail layout (compact, not extended)
          return Scaffold(
            body: Row(
              children: [
                LayoutBuilder(
                  builder: (context, railConstraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: railConstraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: currentIndex,
                            onDestinationSelected: onDestinationSelected,
                            labelType: NavigationRailLabelType.all,
                            destinations: destinations.map((d) {
                              return NavigationRailDestination(
                                icon: d.icon,
                                selectedIcon: d.selectedIcon ?? d.icon,
                                label: Text(d.label),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
      },
    );
  }
}
