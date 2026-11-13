import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/category_model.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/utils/category_similarity.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final CategoryModel? category;
  const CategoryFormDialog({super.key, this.category});
  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _confirmedSimilarName;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
    }
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (!mounted) return;
    setState(() {
      _inlineError = null;
      if (_confirmedSimilarName != _nameController.text.trim()) {
        _confirmedSimilarName = null;
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<CategoryModel> categories) async {
    if (!_formKey.currentState!.validate()) return;
    final trimmedName = _nameController.text.trim();
    if (widget.category != null && trimmedName == widget.category!.name.trim()) {
      Navigator.of(context).pop(false);
      return;
    }

    final exactMatch = CategorySimilarityHelper.findExactMatch(
      trimmedName,
      categories,
      excludeCategoryId: widget.category?.id,
    );
    if (exactMatch != null) {
      setState(() {
        _inlineError =
            'ئەم کاتیگۆرییە پێشتر بە ناوی «${exactMatch.category.name}» بوونی هەیە!';
      });
      return;
    }

    final matches = CategorySimilarityHelper.findMatches(
      trimmedName,
      categories,
      excludeCategoryId: widget.category?.id,
    );
    if (matches.isNotEmpty && _confirmedSimilarName != trimmedName) {
      setState(() {
        _confirmedSimilarName = trimmedName;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });
    try {
      if (widget.category == null) {
        await ref
            .read(categoryActionsProvider)
            .addCategory(trimmedName);
      } else {
        await ref
            .read(categoryActionsProvider)
            .updateCategory(widget.category!.id, trimmedName);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <CategoryModel>[];
    final allProducts = ref.watch(productsListProvider).valueOrNull;
    final Map<int, int>? liveCounts = allProducts == null
        ? null
        : allProducts.fold<Map<int, int>>({}, (map, p) {
            final cid = p.categoryId;
            if (cid != null) {
              map[cid] = (map[cid] ?? 0) + 1;
            }
            return map;
          });

    final trimmed = _nameController.text.trim();
    final isUnchangedEdit = widget.category != null &&
        trimmed == widget.category!.name.trim();
    final matches = isUnchangedEdit
        ? const <CategoryMatch>[]
        : CategorySimilarityHelper.findMatches(
            trimmed,
            categories,
            excludeCategoryId: widget.category?.id,
          );
    final hasExact = matches.any((m) => m.isExact);
    final needsConfirmation =
        !hasExact && matches.isNotEmpty && _confirmedSimilarName == trimmed;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.category == null ? 'زیادکردنی جۆر' : 'دەستکاریکردنی جۆر',
              style: AppTextStyles.h2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  labelText: 'ناوی جۆر',
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(categories),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'ناوی جۆر پێویستە' : null,
                ),
                CategorySimilarityBanner(
                  matches: matches,
                  liveCounts: liveCounts,
                  needsConfirmation: needsConfirmation,
                  inlineError: _inlineError,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          text: needsConfirmation ? 'دڵنیام، پاشەکەوتی بکە' : 'پاشەکەوت',
          isLoading: _isLoading,
          onPressed: () => _submit(categories),
        ),
      ],
    );
  }
}
