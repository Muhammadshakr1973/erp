import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_text_field.dart';

class FilterOption {
  final String id;
  final String label;

  const FilterOption({required this.id, required this.label});
}

class AppSearchFilterBar extends StatelessWidget {
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final TextEditingController? searchController;
  final List<FilterOption>? filters;
  final Set<String>? selectedFilterIds;
  final ValueChanged<Set<String>>? onFiltersChanged;
  final VoidCallback? onClearSearch;
  final Widget? trailing;

  const AppSearchFilterBar({
    Key? key,
    this.searchHint = 'گەڕان...',
    this.onSearchChanged,
    this.searchController,
    this.filters,
    this.selectedFilterIds,
    this.onFiltersChanged,
    this.onClearSearch,
    this.trailing,
  }) : super(key: key);

  void _onChipToggled(String filterId, bool isSelected) {
    if (onFiltersChanged == null || selectedFilterIds == null) return;
    
    final newSelection = Set<String>.from(selectedFilterIds!);
    if (isSelected) {
      newSelection.add(filterId);
    } else {
      newSelection.remove(filterId);
    }
    onFiltersChanged!(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = filters != null && filters!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Row
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: searchController,
                hintText: searchHint,
                prefixIcon: Symbols.search,
                onChanged: onSearchChanged,
                suffixIcon: searchController != null && searchController!.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Symbols.close, size: 18),
                        onPressed: () {
                          searchController!.clear();
                          if (onSearchChanged != null) {
                            onSearchChanged!('');
                          }
                          if (onClearSearch != null) {
                            onClearSearch!();
                          }
                        },
                      )
                    : null,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),

        // Scrollable Filters Row
        if (hasFilters) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filters!.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final filter = filters![index];
                final isSelected = selectedFilterIds?.contains(filter.id) ?? false;

                return Padding(
                  padding: EdgeInsets.only(
                    left: index == filters!.length - 1 ? 0 : 8.0,
                    right: index == 0 ? 4.0 : 0,
                  ),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (selected) => _onChipToggled(filter.id, selected),
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: theme.colorScheme.surface,
                    shadowColor: Colors.transparent,
                    selectedShadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusPill,
                      borderSide: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
