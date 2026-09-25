import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NumericKeyboardState {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool decimal;
  final bool signed;
  final bool isVisible;
  final ValueChanged<String>? onChanged;

  NumericKeyboardState({
    this.controller,
    this.focusNode,
    this.decimal = true,
    this.signed = true,
    this.isVisible = false,
    this.onChanged,
  });

  NumericKeyboardState copyWith({
    TextEditingController? controller,
    FocusNode? focusNode,
    bool? decimal,
    bool? signed,
    bool? isVisible,
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
      onChanged: onChanged,
    );
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
    int cursorPosition = selection.isValid ? selection.baseOffset : text.length;

    if (text.startsWith('-')) {
      newText = text.substring(1);
      if (cursorPosition > 0) cursorPosition--;
    } else {
      newText = '-$text';
      cursorPosition++;
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition >= 0 ? cursorPosition : 0),
    );

    state.onChanged?.call(newText);
  }

  void insert(String char) {
    final controller = state.controller;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;

    // Check decimal constraint
    if (char == '.') {
      if (!state.decimal) return;
      if (text.contains('.')) return;
    }

    String newText;
    int cursorPosition;

    if (selection.isValid && selection.start != selection.end) {
      // Replace selection
      newText = text.replaceRange(selection.start, selection.end, char);
      cursorPosition = selection.start + char.length;
    } else {
      // Insert at cursor or at end
      final pos = selection.isValid ? selection.baseOffset : text.length;
      newText = text.replaceRange(pos, pos, char);
      cursorPosition = pos + char.length;
    }

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

    if (selection.isValid && selection.start != selection.end) {
      // Delete selection
      newText = text.replaceRange(selection.start, selection.end, '');
      cursorPosition = selection.start;
    } else {
      // Delete preceding character
      final pos = selection.isValid ? selection.baseOffset : text.length;
      if (pos == 0) return;
      newText = text.replaceRange(pos - 1, pos, '');
      cursorPosition = pos - 1;
    }

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
