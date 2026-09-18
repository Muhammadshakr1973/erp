import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_durations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

enum SnackbarType { success, error, warning, info }

/// Global top-floating notification toast overlay
class AppSnackbar {
  AppSnackbar._();

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Show a top notification banner above all screens, dialogs, and navigation layers.
  static void show(
    BuildContext? context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    String? title,
    Duration? duration,
  }) {
    // Dismiss any currently showing banner immediately
    _dismissCurrent();

    OverlayState? overlayState;

    if (context != null && context.mounted) {
      try {
        overlayState = Overlay.maybeOf(context, rootOverlay: true);
      } catch (_) {
        overlayState = null;
      }
    }

    // Fallback to root navigator overlay
    overlayState ??= rootNavigatorKey.currentState?.overlay;

    if (overlayState == null) return;

    final displayDuration = duration ?? AppDurations.snackbar;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        title: title,
        type: type,
        duration: displayDuration,
        onDismiss: () {
          if (_activeEntry == entry) {
            _dismissCurrent();
          }
        },
      ),
    );

    _activeEntry = entry;
    overlayState.insert(entry);
  }

  /// Convenience helper for success messages
  static void success(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.success,
      duration: duration,
    );
  }

  /// Convenience helper for error messages
  static void error(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.error,
      duration: duration,
    );
  }

  /// Convenience helper for warning messages
  static void warning(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.warning,
      duration: duration,
    );
  }

  /// Convenience helper for info messages
  static void info(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.info,
      duration: duration,
    );
  }

  /// Manually dismiss current notification
  static void hide() {
    _dismissCurrent();
  }

  static void _dismissCurrent() {
    _activeTimer?.cancel();
    _activeTimer = null;
    if (_activeEntry != null) {
      try {
        _activeEntry!.remove();
      } catch (_) {}
      _activeEntry = null;
    }
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final String? title;
  final SnackbarType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();

    // Auto-dismiss timer
    _dismissTimer = Timer(widget.duration, () {
      _dismissWithAnimation();
    });
  }

  void _dismissWithAnimation() {
    _dismissTimer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case SnackbarType.success:
        return const Color(0xFF0D9488); // Teal/Emerald
      case SnackbarType.error:
        return AppColors.danger;
      case SnackbarType.warning:
        return const Color(0xFFD97706); // Amber
      case SnackbarType.info:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case SnackbarType.success:
        return Symbols.check_circle;
      case SnackbarType.error:
        return Symbols.error;
      case SnackbarType.warning:
        return Symbols.warning;
      case SnackbarType.info:
        return Symbols.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final icon = _getIcon();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta != null && details.primaryDelta! < -4) {
                      _dismissWithAnimation();
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      color: bgColor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.title != null &&
                                        widget.title!.isNotEmpty) ...[
                                      Text(
                                        widget.title!,
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      widget.message,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: _dismissWithAnimation,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
