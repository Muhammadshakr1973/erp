import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/category_model.dart';
import '../../products/providers/categories_provider.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final trimmedName = _nameController.text.trim();
    if (widget.category != null && trimmedName == widget.category!.name.trim()) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _isLoading = true);
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
      content: Form(
        key: _formKey,
        child: AppTextField(
          labelText: 'ناوی جۆر',
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'ناوی جۆر پێویستە' : null,
        ),
      ),
      actions: [
        AppButton(text: 'پاشەکەوت', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}
