import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_text_styles.dart';
import '../utils/notification_sound_service.dart';
import 'app_button.dart';
import 'app_snackbar.dart';

/// Professional Camera Barcode & QR Scanner Component
/// Designed for GARDI ERP with multi-platform support (Web, Android, iOS, Desktop)
/// Supports camera streaming, physical USB/Bluetooth barcode guns, and manual input.
class CameraBarcodeScanner extends StatefulWidget {
  final Function(String barcode) onScan;

  const CameraBarcodeScanner({super.key, required this.onScan});

  static Future<void> show(BuildContext context, Function(String) onScan) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final isMobile = mediaQuery.size.width < 600;
        final dialogWidth = isMobile ? mediaQuery.size.width * 0.94 : 480.0;
        final dialogHeight = isMobile ? mediaQuery.size.height * 0.85 : 620.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CameraBarcodeScanner(onScan: onScan),
          ),
        );
      },
    );
  }

  @override
  State<CameraBarcodeScanner> createState() => _CameraBarcodeScannerState();
}

class _CameraBarcodeScannerState extends State<CameraBarcodeScanner>
    with SingleTickerProviderStateMixin {
  final TextEditingController _manualInputController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _manualInputFocusNode = FocusNode();
  final StringBuffer _scannerGunBuffer = StringBuffer();

  MobileScannerController? _scannerController;
  late AnimationController _laserController;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _currentFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initializeController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  void _initializeController() {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: _currentFacing,
        autoStart: true,
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.code128,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.codabar,
          BarcodeFormat.itf,
        ],
      );
    } catch (e) {
      debugPrint("Scanner controller initialization error: $e");
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _manualInputController.dispose();
    _keyboardFocusNode.dispose();
    _manualInputFocusNode.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  /// Handles barcode detection from camera, hardware scanner gun, or manual entry
  void _onSuccessScan(String rawCode) {
    if (_isProcessing) return;
    final barcode = rawCode.trim();
    if (barcode.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      NotificationSoundService.playNotificationSound();
    } catch (_) {}

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    widget.onScan(barcode);

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    AppSnackbar.show(
      context,
      message: 'بارکۆد بە سەرکەوتوویی خوێندرایەوە: $barcode',
      type: SnackbarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  /// Captures physical USB/Bluetooth barcode scanner gun input (HID keyboard emulation)
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;

      if (logicalKey == LogicalKeyboardKey.enter) {
        if (_scannerGunBuffer.isNotEmpty) {
          final scannedCode = _scannerGunBuffer.toString();
          _scannerGunBuffer.clear();
          _onSuccessScan(scannedCode);
        } else if (_manualInputController.text.trim().isNotEmpty) {
          _onSuccessScan(_manualInputController.text.trim());
        }
      } else {
        final character = event.character;
        if (character != null && character.isNotEmpty) {
          _scannerGunBuffer.write(character);
        }
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_scannerController == null) return;
    try {
      await _scannerController!.toggleTorch();
      if (mounted) {
        setState(() {
          _isTorchOn = !_isTorchOn;
        });
      }
    } catch (e) {
      debugPrint("Error toggling torch: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (_scannerController == null) return;
    try {
      await _scannerController!.switchCamera();
      if (mounted) {
        setState(() {
          _currentFacing = _currentFacing == CameraFacing.back
              ? CameraFacing.front
              : CameraFacing.back;
        });
      }
    } catch (e) {
      debugPrint("Error switching camera: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'خوێندنەوەی بارکۆد',
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _isTorchOn ? 'کوژاندنەوەی فلاش' : 'داگیرساندنی فلاش',
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleTorch,
                    ),
                    IconButton(
                      tooltip: 'گۆڕینی کامێرا',
                      icon: Icon(
                        Icons.cameraswitch_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _switchCamera,
                    ),
                    IconButton(
                      tooltip: 'داخستن',
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Viewfinder & Full Camera Viewport
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: _scannerController == null
                      ? _buildScannerUnavailable(theme)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final boxSize = (constraints.maxWidth * 0.72)
                                .clamp(200.0, 280.0);
                            final left = (constraints.maxWidth - boxSize) / 2;
                            final top = (constraints.maxHeight - boxSize) / 2;
                            final scanWindow = Rect.fromLTWH(left, top, boxSize, boxSize);

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Camera Video Feed (Full width and height, cover fit)
                                Positioned.fill(
                                  child: MobileScanner(
                                    controller: _scannerController!,
                                    fit: BoxFit.cover,
                                    onDetect: (capture) {
                                      final List<Barcode> barcodes = capture.barcodes;
                                      for (final b in barcodes) {
                                        final code = b.rawValue;
                                        if (code != null && code.trim().isNotEmpty) {
                                          _onSuccessScan(code.trim());
                                          break;
                                        }
                                      }
                                    },
                                    errorBuilder: (context, error, child) {
                                      return _buildCameraError(theme, error);
                                    },
                                  ),
                                ),

                                // Professional Frosted Cutout Overlay with Corner Accents
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: ScannerOverlayPainter(
                                      scanWindow: scanWindow,
                                      borderRadius: 20,
                                      overlayColor: Colors.black.withValues(alpha: 0.58),
                                      borderColor: theme.colorScheme.primary,
                                      borderWidth: 3.5,
                                      cornerLength: 32,
                                    ),
                                  ),
                                ),

                                // Animated Scanning Laser Line
                                AnimatedBuilder(
                                  animation: _laserController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: scanWindow.top + 8 +
                                          (_laserController.value * (scanWindow.height - 20)),
                                      left: scanWindow.left + 12,
                                      width: scanWindow.width - 24,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary.withValues(alpha: 0.0),
                                              theme.colorScheme.primary,
                                              theme.colorScheme.primary,
                                              theme.colorScheme.primary.withValues(alpha: 0.0),
                                            ],
                                            stops: const [0.0, 0.2, 0.8, 1.0],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // User Instruction Badge
                                Positioned(
                                  top: scanWindow.bottom + 20,
                                  left: 20,
                                  right: 20,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.center_focus_strong_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'بارکۆد یان QR کۆد لەناو چوارچێوەکەدا ڕابگرە',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),

              // Manual Input & Barcode Gun Support Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualInputController,
                        focusNode: _manualInputFocusNode,
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'کۆدی بارکۆد بە دەست بنووسە...',
                          prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _onSuccessScan(value.trim());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      text: 'لێدان',
                      icon: Icons.check_circle_outline,
                      onPressed: () {
                        if (_manualInputController.text.trim().isNotEmpty) {
                          _onSuccessScan(_manualInputController.text.trim());
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(ThemeData theme, MobileScannerException error) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                size: 40,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'دەستڕاگەیشتن بە کامێرا سەرکەوتوو نەبوو',
              style: AppTextStyles.h3.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تکایە دڵنیابەرەوە لە پێدانی مۆڵەتی کامێرا بە وێبگەڕ یان ئامێرەکەت، یان کۆدەکان بە دەست بنووسە.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('دووبارە هەوڵدانەوە'),
                  onPressed: () async {
                    try {
                      await _scannerController?.start();
                    } catch (_) {}
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cameraswitch_rounded, size: 18),
                  label: const Text('گۆڕینی کامێرا'),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerUnavailable(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'سکانەری ئامێر یان سکانەری بێسیم ئامادەیە',
              style: AppTextStyles.h3.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'دەتوانیت بارکۆدەکە سکان بکەیت یان لە خوارەوە بە دەست بنووسیت.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that creates a darkened overlay with a clear rounded rectangular cutout
/// and sleek corner brackets for barcode alignment
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerLength;

  ScannerOverlayPainter({
    required this.scanWindow,
    this.borderRadius = 20.0,
    this.overlayColor = const Color(0x99000000),
    this.borderColor = const Color(0xFF2563EB),
    this.borderWidth = 3.5,
    this.cornerLength = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );
    final cutoutPath = Path()..addRRect(cutoutRRect);

    // Subtract the cutout from the full background
    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, overlayPaint);

    // Subtle hairline inner border
    final subtleBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(cutoutRRect, subtleBorderPaint);

    // Corner bracket accents
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final left = scanWindow.left;
    final top = scanWindow.top;
    final right = scanWindow.right;
    final bottom = scanWindow.bottom;
    final r = borderRadius;
    final cl = cornerLength;

    // Top-left
    final topLeft = Path()
      ..moveTo(left, top + cl)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..lineTo(left + cl, top);
    canvas.drawPath(topLeft, cornerPaint);

    // Top-right
    final topRight = Path()
      ..moveTo(right - cl, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, top + cl);
    canvas.drawPath(topRight, cornerPaint);

    // Bottom-left
    final bottomLeft = Path()
      ..moveTo(left, bottom - cl)
      ..lineTo(left, bottom - r)
      ..arcToPoint(Offset(left + r, bottom), radius: Radius.circular(r))
      ..lineTo(left + cl, bottom);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Bottom-right
    final bottomRight = Path()
      ..moveTo(right - cl, bottom)
      ..lineTo(right - r, bottom)
      ..arcToPoint(Offset(right, bottom - r), radius: Radius.circular(r))
      ..lineTo(right, bottom - cl);
    canvas.drawPath(bottomRight, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderColor != borderColor;
  }
}
