import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Kurdish localization and interaction safeguard for Flutter's text selection context menu.
/// Translates system text toolbar buttons to Kurdish Sorani (بڕین، کۆپیکردن، لکاندن / پەیست، دیاریکردنی هەمووی)
/// and resolves tap-outside / unfocus conflicts on Linux, Android (APK), and desktop environments.
class KurdishContextMenu {
  /// Translates button types and common Arabic/English system labels to Kurdish Sorani
  static String getLabel(ContextMenuButtonItem item) {
    switch (item.type) {
      case ContextMenuButtonType.cut:
        return 'بڕین';
      case ContextMenuButtonType.copy:
        return 'کۆپیکردن';
      case ContextMenuButtonType.paste:
        return 'لکاندن / پەیست';
      case ContextMenuButtonType.selectAll:
        return 'دیاریکردنی هەمووی';
      case ContextMenuButtonType.delete:
        return 'سڕینەوە';
      case ContextMenuButtonType.share:
        return 'هاوبەشکردن';
      case ContextMenuButtonType.lookUp:
        return 'گەڕان';
      case ContextMenuButtonType.searchWeb:
        return 'گەڕان لە وێب';
      case ContextMenuButtonType.liveTextInput:
        return 'دەقی ڕاستەوخۆ';
      case ContextMenuButtonType.custom:
        final raw = item.label ?? '';
        if (raw.contains('لصق') || raw.toLowerCase().contains('paste')) {
          return 'لکاندن / پەیست';
        }
        if (raw.contains('اختيار الكل') ||
            raw.contains('تحديد الكل') ||
            raw.toLowerCase().contains('select all')) {
          return 'دیاریکردنی هەمووی';
        }
        if (raw.contains('نسخ') || raw.toLowerCase().contains('copy')) {
          return 'کۆپیکردن';
        }
        if (raw.contains('قص') || raw.toLowerCase().contains('cut')) {
          return 'بڕین';
        }
        if (raw.contains('حذف') || raw.toLowerCase().contains('delete')) {
          return 'سڕینەوە';
        }
        return raw.isNotEmpty ? raw : 'هەڵبژاردن';
    }
  }

  /// Builds the context menu with Kurdish labels and wraps in TapRegion to prevent unfocus
  static Widget build(
    BuildContext context,
    EditableTextState editableTextState, {
    FocusNode? focusNode,
    Object? tapRegionGroupId,
  }) {
    if (kIsWeb) return const SizedBox.shrink();

    final originalItems = editableTextState.contextMenuButtonItems;
    if (originalItems.isEmpty) return const SizedBox.shrink();

    final kurdishItems = originalItems.map((item) {
      return ContextMenuButtonItem(
        type: item.type,
        label: getLabel(item),
        onPressed: () {
          if (focusNode != null && !focusNode.hasFocus) {
            focusNode.requestFocus();
          }
          item.onPressed?.call();
        },
      );
    }).toList();

    final Widget toolbar = Directionality(
      textDirection: TextDirection.rtl,
      child: AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: kurdishItems,
      ),
    );

    if (tapRegionGroupId != null) {
      return TapRegion(
        groupId: tapRegionGroupId,
        child: toolbar,
      );
    }

    return toolbar;
  }
}
