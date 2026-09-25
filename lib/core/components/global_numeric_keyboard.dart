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

    // Verify screen is mobile or tablet (< 1024 width)
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return const SizedBox.shrink();
    }

    final double keyboardHeight = 290;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        elevation: 24,
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFD1D5DB),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: keyboardHeight,
            child: Column(
              children: [
                // iOS-Style Accessory Toolbar with Done and Backspace
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Done Button (Kurdish: تەواو)
                      TextButton(
                        onPressed: () {
                          ref.read(numericKeyboardProvider.notifier).hide();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'تەواو',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Backspace Button
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        color: isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ref.read(numericKeyboardProvider.notifier).delete();
                        },
                      ),
                    ],
                  ),
                ),
                // Keyboard Key Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
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
        padding: const EdgeInsets.all(4),
        child: Material(
          color: buttonColor,
          borderRadius: BorderRadius.circular(6),
          elevation: 1,
          child: InkWell(
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
    final state = ref.watch(numericKeyboardProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileOrTablet = screenWidth < 1024.0;

    final double keyboardHeight = (state.isVisible && isMobileOrTablet) ? 290 : 0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: MediaQuery.of(context).viewInsets.copyWith(
          bottom: keyboardHeight + MediaQuery.of(context).viewInsets.bottom,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: child,
          ),
          if (state.isVisible && isMobileOrTablet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {}, // Swallows taps on the keyboard background itself
                behavior: HitTestBehavior.opaque,
                child: const GlobalNumericKeyboard(),
              ),
            ),
        ],
      ),
    );
  }
}
