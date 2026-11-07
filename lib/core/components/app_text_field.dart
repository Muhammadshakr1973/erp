import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import 'numeric_keyboard_manager.dart';
import 'global_numeric_keyboard.dart';

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
  final bool autofocus;
  final TextAlign? textAlign;
  final TextStyle? style;
  final VoidCallback? onLongPress;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

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
    this.autofocus = false,
    this.textAlign,
    this.style,
    this.onLongPress,
    this.contextMenuBuilder,
  });

  @override
  ConsumerState<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends ConsumerState<AppTextField> {
  FocusNode? _localFocusNode;
  TextEditingController? _localController;
  bool _isDialogShowing = false;

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
    try {
      final keyboardNotifier = ref.read(numericKeyboardProvider.notifier);
      final keyboardState = ref.read(numericKeyboardProvider);
      if (keyboardState.controller == _effectiveController) {
        keyboardNotifier.hideKeyboardOnly();
      }
    } catch (_) {}
    _localFocusNode?.dispose();
    _localController?.dispose();
    super.dispose();
  }

  bool get _isNumeric {
    final type = widget.keyboardType;
    if (type == TextInputType.number ||
        type == TextInputType.phone ||
        type == const TextInputType.numberWithOptions(decimal: true) ||
        type == const TextInputType.numberWithOptions(signed: true) ||
        type == const TextInputType.numberWithOptions(decimal: true, signed: true)) {
      return true;
    }
    final typeStr = type.toString().toLowerCase();
    return typeStr.contains('number') || typeStr.contains('phone');
  }

  void _triggerNumericKeyboard() {
    if (!_isNumeric) return;

    // Clean any accidental trailing .0 before opening keyboard dialog
    final rawText = _effectiveController.text;
    final cleaned = Formatters.cleanNumberString(rawText);
    if (cleaned != rawText && (rawText.endsWith('.0') || rawText.endsWith('.00') || rawText.endsWith('.000'))) {
      _effectiveController.text = cleaned;
    }

    ref.read(numericKeyboardProvider.notifier).register(
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          decimal: true, // Always allow decimals on our custom layout
          signed: true,  // Always allow negative sign on our custom layout
          onChanged: widget.onChanged,
        );
    _showKeyboardDialog();
  }

  void _onFocusChange() {
    final bool isNumeric = _isNumeric;
    if (_effectiveFocusNode.hasFocus) {
      if (isNumeric) {
        _triggerNumericKeyboard();
      } else {
        // If a non-numeric field is focused, immediately hide the custom numeric keyboard
        ref.read(numericKeyboardProvider.notifier).hideKeyboardOnly();
      }
    }
  }

  void _showKeyboardDialog() {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    // Immediately dismiss any soft keyboard from the platform
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return NumericKeyboardDialog(
          controller: _effectiveController,
          labelText: widget.labelText,
          hintText: widget.hintText,
          onChanged: widget.onChanged,
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      if (mounted) {
        _effectiveFocusNode.unfocus();
        ref.read(numericKeyboardProvider.notifier).hideKeyboardOnly();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(24);

    final bool isNumeric = _isNumeric;
    final bool isReadOnly = (widget.readOnly ?? false) || isNumeric;
    final TextInputType effectiveKeyboardType = isNumeric
        ? TextInputType.none
        : widget.keyboardType;

    return TapRegion(
      groupId: _effectiveFocusNode,
      onTapOutside: (event) {
        if (_isDialogShowing) return;
        // If the user tapped completely outside the input field, unfocus it.
        if (_effectiveFocusNode.hasFocus) {
          _effectiveFocusNode.unfocus();
          ref.read(numericKeyboardProvider.notifier).hideKeyboardOnly();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: widget.onLongPress,
        child: TextFormField(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        contextMenuBuilder: widget.contextMenuBuilder ??
            (context, editableTextState) {
              if (kIsWeb) {
                return const SizedBox.shrink();
              }
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: editableTextState.contextMenuButtonItems,
              );
            },
        keyboardType: effectiveKeyboardType,
        obscureText: widget.obscureText,
        readOnly: isReadOnly,
        canRequestFocus: !isNumeric,
        enableInteractiveSelection: !isNumeric,
        showCursor: !isNumeric,
        onTap: () {
          if (isNumeric) {
            _triggerNumericKeyboard();
          }
        },
        textDirection: _isNumeric ? TextDirection.ltr : null,
        textAlign: widget.textAlign ?? (_isNumeric ? TextAlign.right : TextAlign.start),
        autofocus: widget.autofocus,
        autocorrect: !_isNumeric,
        enableSuggestions: !_isNumeric,
        validator: widget.validator,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: widget.style ??
            AppTextStyles.bodyMedium.copyWith(
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
      ),
      ),
    );
  }
}
