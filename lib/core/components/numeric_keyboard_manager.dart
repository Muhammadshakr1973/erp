import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NumericKeyboardState {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool decimal;
  final bool signed;
  final bool isVisible;
  final bool isTappingKeyboard;
  final ValueChanged<String>? onChanged;

  NumericKeyboardState({
    this.controller,
    this.focusNode,
    this.decimal = true,
    this.signed = true,
    this.isVisible = false,
    this.isTappingKeyboard = false,
    this.onChanged,
  });

  NumericKeyboardState copyWith({
    TextEditingController? controller,
    FocusNode? focusNode,
    bool? decimal,
    bool? signed,
    bool? isVisible,
    bool? isTappingKeyboard,
    ValueChanged<String>? onChanged,
    bool clearAll = false,
  }) {
    if (clearAll) {
      return NumericKeyboardState();
    }
    return NumericKeyboardState(
      controller: controller ?? this.controller,
      focusNode: focusNode ?? this.focusNode,
      decimal: decimal ?? this.decimal,
      signed: signed ?? this.signed,
      isVisible: isVisible ?? this.isVisible,
      isTappingKeyboard: isTappingKeyboard ?? this.isTappingKeyboard,
      onChanged: onChanged ?? this.onChanged,
    );
  }
}

class NumericKeyboardNotifier extends StateNotifier<NumericKeyboardState> {
  TextSelection? _lastSelection;

  NumericKeyboardNotifier() : super(NumericKeyboardState());

  void _handleControllerSelectionChange() {
    final controller = state.controller;
    if (controller != null) {
      if (!state.isTappingKeyboard) {
        _lastSelection = controller.selection;
      }
    }
  }

  void _removeListener() {
    if (state.controller != null) {
      state.controller!.removeListener(_handleControllerSelectionChange);
    }
  }

  void register({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool decimal,
    required bool signed,
    ValueChanged<String>? onChanged,
  }) {
    if (state.controller != controller) {
      _removeListener();
    }

    // Position the cursor at the end of the text to ensure natural appending and deleting
    final text = controller.text;
    controller.selection = TextSelection.collapsed(offset: text.length);
    _lastSelection = controller.selection;

    if (state.controller != controller) {
      controller.addListener(_handleControllerSelectionChange);
    }

    state = NumericKeyboardState(
      controller: controller,
      focusNode: focusNode,
      decimal: decimal,
      signed: signed,
      isVisible: true,
      isTappingKeyboard: state.isTappingKeyboard, // Preserve tapping status during focus fluctuation
      onChanged: onChanged,
    );
  }

  void setTapping(bool tapping) {
    state = state.copyWith(isTappingKeyboard: tapping);
  }

  void hide() {
    if (state.focusNode != null) {
      state.focusNode!.unfocus();
    }
    _removeListener();
    _lastSelection = null;
    state = state.copyWith(isVisible: false);
  }

  void hideKeyboardOnly() {
    _removeListener();
    _lastSelection = null;
    state = state.copyWith(isVisible: false);
  }

  void toggleSign() {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = (_lastSelection != null &&
            _lastSelection!.isValid &&
            _lastSelection!.start <= text.length &&
            _lastSelection!.end <= text.length)
        ? _lastSelection!
        : controller.selection;

    String newText;
    
    // Sanitize cursor position
    int cursorPosition = selection.isValid ? selection.baseOffset : text.length;
    if (cursorPosition < 0) cursorPosition = 0;
    if (cursorPosition > text.length) cursorPosition = text.length;

    if (text.startsWith('-')) {
      newText = text.substring(1);
      if (cursorPosition > 0) cursorPosition--;
    } else {
      newText = '-$text';
      cursorPosition++;
    }

    if (cursorPosition < 0) cursorPosition = 0;
    if (cursorPosition > newText.length) cursorPosition = newText.length;

    final newSelection = TextSelection.collapsed(offset: cursorPosition);
    _lastSelection = newSelection;

    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    state.onChanged?.call(newText);
  }

  void insert(String char) {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = (_lastSelection != null &&
            _lastSelection!.isValid &&
            _lastSelection!.start <= text.length &&
            _lastSelection!.end <= text.length)
        ? _lastSelection!
        : controller.selection;

    // Sanitize start and end of selection
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;
    
    if (start < 0) start = 0;
    if (start > text.length) start = text.length;
    if (end < 0) end = 0;
    if (end > text.length) end = text.length;
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final String textRemaining = text.replaceRange(start, end, '');

    // Check decimal constraint
    if (char == '.') {
      if (!state.decimal) return;
      if (textRemaining.contains('.')) return;
    }

    String newText;
    int cursorPosition;

    if (start != end) {
      // Replace selection
      newText = text.replaceRange(start, end, char);
      cursorPosition = start + char.length;
    } else {
      // Insert at cursor or at end
      newText = text.replaceRange(start, start, char);
      cursorPosition = start + char.length;
    }

    if (cursorPosition < 0) cursorPosition = 0;
    if (cursorPosition > newText.length) cursorPosition = newText.length;

    final newSelection = TextSelection.collapsed(offset: cursorPosition);
    _lastSelection = newSelection;

    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    state.onChanged?.call(newText);
  }

  void delete() {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = (_lastSelection != null &&
            _lastSelection!.isValid &&
            _lastSelection!.start <= text.length &&
            _lastSelection!.end <= text.length)
        ? _lastSelection!
        : controller.selection;

    if (text.isEmpty) return;

    String newText;
    int cursorPosition;

    // Sanitize start and end of selection
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    if (start < 0) start = 0;
    if (start > text.length) start = text.length;
    if (end < 0) end = 0;
    if (end > text.length) end = text.length;
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    if (start != end) {
      // Delete selection
      newText = text.replaceRange(start, end, '');
      cursorPosition = start;
    } else {
      // Delete preceding character
      if (start == 0) return;
      newText = text.replaceRange(start - 1, start, '');
      cursorPosition = start - 1;
    }

    if (cursorPosition < 0) cursorPosition = 0;
    if (cursorPosition > newText.length) cursorPosition = newText.length;

    final newSelection = TextSelection.collapsed(offset: cursorPosition);
    _lastSelection = newSelection;

    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    state.onChanged?.call(newText);
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }
}

final numericKeyboardProvider =
    StateNotifierProvider<NumericKeyboardNotifier, NumericKeyboardState>((ref) {
  return NumericKeyboardNotifier();
});
