import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_text_styles.dart';
import 'numeric_keyboard_manager.dart';

class GlobalNumericKeyboard extends ConsumerWidget {
  const GlobalNumericKeyboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(numericKeyboardProvider);
    if (!state.isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double keyboardHeight = 250;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Listener(
        onPointerDown: (_) {
          ref.read(numericKeyboardProvider.notifier).setTapping(true);
        },
        onPointerUp: (_) {
          ref.read(numericKeyboardProvider.notifier).setTapping(false);
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E7EB),
          child: Container(
          height: keyboardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // iOS-Style Accessory Toolbar with Done and Backspace
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Done Button (Kurdish: تەواو)
                    InkWell(
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        ref.read(numericKeyboardProvider.notifier).hide();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          'تەواو',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    // Backspace Button
                    InkWell(
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        ref.read(numericKeyboardProvider.notifier).delete();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Icon(
                          Icons.backspace_outlined,
                          color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Keyboard Key Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildKey(context, ref, '1'),
                            _buildKey(context, ref, '2'),
                            _buildKey(context, ref, '3'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildKey(context, ref, '4'),
                            _buildKey(context, ref, '5'),
                            _buildKey(context, ref, '6'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildKey(context, ref, '7'),
                            _buildKey(context, ref, '8'),
                            _buildKey(context, ref, '9'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildKey(context, ref, '-', isSpecial: true),
                            _buildKey(context, ref, '0'),
                            _buildKey(context, ref, '.', isSpecial: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildKey(
    BuildContext context,
    WidgetRef ref,
    String label, {
    bool isSpecial = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color buttonColor;
    if (isDark) {
      buttonColor = isSpecial ? const Color(0xFF3A3A3C) : const Color(0xFF636366);
    } else {
      buttonColor = isSpecial ? const Color(0xFFB0B3B8) : Colors.white;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: buttonColor,
          borderRadius: BorderRadius.circular(6),
          elevation: 1,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              if (label == '-') {
                ref.read(numericKeyboardProvider.notifier).toggleSign();
              } else {
                ref.read(numericKeyboardProvider.notifier).insert(label);
              }
            },
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalNumericKeyboardWrapper extends ConsumerWidget {
  final Widget child;

  const GlobalNumericKeyboardWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The keyboard is now displayed as a dropdown linked to each AppTextField, so the global screen-bottom keyboard is disabled.
    return child;
  }
}
