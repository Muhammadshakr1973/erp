import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/category_model.dart';
import '../../products/providers/categories_provider.dart';
import 'category_form_dialog.dart';

class AdminCategoriesDialog extends ConsumerWidget {
  const AdminCategoriesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بەڕێوەبردنی جۆرەکان', style: AppTextStyles.h2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(AppIcons.add, color: AppColors.primary),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const CategoryFormDialog(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('هیچ جۆرێک نییە'));
                    }
                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: ListTile(
                              title: Text(cat.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      AppIcons.edit,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            CategoryFormDialog(category: cat),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      AppIcons.delete,
                                      color: AppColors.danger,
                                    ),
                                    onPressed: () =>
                                        _deleteCategory(context, ref, cat),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(
                    child: Text(
                      e.toString(),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('سڕینەوەی جۆر')),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: Text('دڵنیایت لە سڕینەوەی جۆری "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(categoryActionsProvider)
                    .deleteCategory(category.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'سڕینەوە',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
