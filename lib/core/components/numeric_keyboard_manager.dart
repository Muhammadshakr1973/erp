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
  NumericKeyboardNotifier() : super(NumericKeyboardState());

  void register({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool decimal,
    required bool signed,
    ValueChanged<String>? onChanged,
  }) {
    state = NumericKeyboardState(
      controller: controller,
      focusNode: focusNode,
      decimal: decimal,
      signed: signed,
      isVisible: true,
      isTappingKeyboard: false,
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
    state = state.copyWith(isVisible: false);
  }

  void hideKeyboardOnly() {
    state = state.copyWith(isVisible: false);
  }

  void toggleSign() {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
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

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

    state.onChanged?.call(newText);
  }

  void insert(String char) {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;

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

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

    state.onChanged?.call(newText);
  }

  void delete() {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;

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

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

    state.onChanged?.call(newText);
  }
}

final numericKeyboardProvider =
    StateNotifierProvider<NumericKeyboardNotifier, NumericKeyboardState>((ref) {
  return NumericKeyboardNotifier();
});
