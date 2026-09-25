import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'numeric_keyboard_manager.dart';

class AppTextField extends ConsumerStatefulWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final BorderRadius? borderRadius;
  final bool? readOnly;
  final InputDecoration? customDecoration;

  const AppTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.textInputAction,
    this.onFieldSubmitted,
    this.borderRadius,
    this.readOnly,
    this.customDecoration,
  });

  @override
  ConsumerState<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends ConsumerState<AppTextField> {
  FocusNode? _localFocusNode;
  TextEditingController? _localController;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_localFocusNode ??= FocusNode());
  TextEditingController get _effectiveController => widget.controller ?? (_localController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      _effectiveFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _localFocusNode?.dispose();
    _localController?.dispose();
    super.dispose();
  }

  bool get _isNumeric {
    final typeStr = widget.keyboardType.toString().toLowerCase();
    return typeStr.contains('number') || typeStr.contains('phone');
  }

  void _onFocusChange() {
    if (_effectiveFocusNode.hasFocus && _isNumeric) {
      final screenWidth = MediaQuery.of(context).size.width;
      final bool isMobileOrTablet = screenWidth < 1024.0;
      if (isMobileOrTablet) {
        ref.read(numericKeyboardProvider.notifier).register(
              controller: _effectiveController,
              focusNode: _effectiveFocusNode,
              decimal: true, // Always allow decimals on our custom iOS layout
              signed: true,  // Always allow negative sign on our custom iOS layout
              onChanged: widget.onChanged,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(24);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileOrTablet = screenWidth < 1024.0;

    final bool isReadOnly = widget.readOnly ?? false;
    final TextInputType effectiveKeyboardType = (isMobileOrTablet && _isNumeric)
        ? TextInputType.none
        : widget.keyboardType;

    return TextFormField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      keyboardType: effectiveKeyboardType,
      obscureText: widget.obscureText,
      readOnly: isReadOnly,
      showCursor: true,
      enableInteractiveSelection: true,
      validator: widget.validator,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: AppTextStyles.bodyMedium.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: widget.customDecoration ??
          InputDecoration(
            labelText: widget.labelText,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            hintText: widget.hintText,
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: 20.0,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
            suffixIcon: widget.suffixIcon,
            errorText: widget.errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
    );
  }
}
