import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_text_styles.dart';
import '../utils/notification_sound_service.dart';
import 'app_button.dart';
import 'app_snackbar.dart';

/// Professional, fully responsive Edge-to-Edge Camera Barcode & QR Scanner Component
/// Designed for GARDI ERP with multi-platform support (Web, Android, iOS, Desktop)
/// Supports camera streaming, physical USB/Bluetooth barcode guns, and manual input.
class CameraBarcodeScanner extends StatefulWidget {
  final Function(String barcode) onScan;
  final bool isFullscreen;

  const CameraBarcodeScanner({
    super.key,
    required this.onScan,
    this.isFullscreen = false,
  });

  /// Opens the scanner in True Fullscreen mode on mobile devices,
  /// or an expansive centered modal on desktop/tablets.
  static Future<void> show(BuildContext context, Function(String barcode) onScan) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 700;

    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: CameraBarcodeScanner(
              onScan: onScan,
              isFullscreen: true,
            ),
          ),
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (ctx) {
          const dialogWidth = 540.0;
          const dialogHeight = 680.0;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 36,
                    spreadRadius: 6,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CameraBarcodeScanner(
                onScan: onScan,
                isFullscreen: false,
              ),
            ),
          );
        },
      );
    }
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
  double _zoomScale = 1.0;
  bool _showManualField = false;
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

  Future<void> _toggleZoom() async {
    if (_scannerController == null) return;
    try {
      final nextZoom = _zoomScale == 1.0 ? 2.0 : 1.0;
      await _scannerController!.setZoomScale(nextZoom);
      if (mounted) {
        setState(() {
          _zoomScale = nextZoom;
        });
      }
    } catch (e) {
      debugPrint("Error toggling zoom: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          // Responsive calculation for scan reticle window:
          // Optimized for both wide 1D barcodes and 2D QR codes
          final boxWidth = (availableWidth * 0.78).clamp(240.0, 340.0);
          final boxHeight = (boxWidth * 0.72).clamp(180.0, 260.0);

          final left = (availableWidth - boxWidth) / 2;
          final top = (availableHeight - boxHeight) / 2 - (widget.isFullscreen ? 20 : 0);
          final scanWindow = Rect.fromLTWH(left, top, boxWidth, boxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. FULL VIEWPORT CAMERA BACKGROUND (Zero-squeeze, edge-to-edge)
              Positioned.fill(
                child: _scannerController == null
                    ? _buildScannerUnavailable(theme)
                    : MobileScanner(
                        controller: _scannerController!,
                        fit: BoxFit.cover,
                        scanWindow: scanWindow,
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

              // 2. PROFESSIONAL FROSTED CUTOUT OVERLAY & CORNER ACCENTS
              Positioned.fill(
                child: CustomPaint(
                  painter: ScannerOverlayPainter(
                    scanWindow: scanWindow,
                    borderRadius: 22,
                    overlayColor: Colors.black.withValues(alpha: 0.58),
                    borderColor: theme.colorScheme.primary,
                    borderWidth: 4.0,
                    cornerLength: 36,
                  ),
                ),
              ),

              // 3. ANIMATED SCANNING LASER BEAM
              AnimatedBuilder(
                animation: _laserController,
                builder: (context, child) {
                  return Positioned(
                    top: scanWindow.top + 8 +
                        (_laserController.value * (scanWindow.height - 20)),
                    left: scanWindow.left + 12,
                    width: scanWindow.width - 24,
                    child: Container(
                      height: 3.5,
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
                            color: theme.colorScheme.primary.withValues(alpha: 0.9),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // 4. FLOATING TOP HUD BAR (Safe area, translucent glassmorphic design)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Close / Back button
                              _buildGlassIconButton(
                                icon: widget.isFullscreen
                                    ? Icons.arrow_back_rounded
                                    : Icons.close_rounded,
                                tooltip: 'داخستن',
                                onPressed: () {
                                  if (mounted && Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),

                              // Title & Live Scanner Pulse
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.greenAccent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.greenAccent.withValues(alpha: 0.8),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'سکانەری بارکۆد',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quick Zoom Toggle (1x / 2x)
                              _buildGlassIconButton(
                                text: '${_zoomScale.toInt()}x',
                                tooltip: 'نزیککردنەوە (Zoom)',
                                onPressed: _toggleZoom,
                              ),
                              const SizedBox(width: 6),

                              // Flashlight / Torch toggle
                              _buildGlassIconButton(
                                icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                iconColor: _isTorchOn ? Colors.amberAccent : Colors.white,
                                tooltip: _isTorchOn ? 'کوژاندنەوەی فلاش' : 'داگیرساندنی فلاش',
                                onPressed: _toggleTorch,
                              ),
                              const SizedBox(width: 6),

                              // Camera Flip Toggle
                              _buildGlassIconButton(
                                icon: Icons.cameraswitch_rounded,
                                tooltip: 'گۆڕینی کامێرا',
                                onPressed: _switchCamera,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 5. USER GUIDANCE BADGE (Placed underneath the reticle)
              Positioned(
                top: scanWindow.bottom + 18,
                left: 20,
                right: 20,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.center_focus_strong_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'بارکۆد یان QR لەناو چوارچێوەکە ڕابگرە',
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
                ),
              ),

              // 6. FLOATING BOTTOM HUD CONTROLS (Manual Input & Barcode Gun Support)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Collapsible/Expandable Manual Input Field
                        if (_showManualField)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _manualInputController,
                                          focusNode: _manualInputFocusNode,
                                          style: const TextStyle(color: Colors.white),
                                          autofocus: true,
                                          keyboardType: TextInputType.text,
                                          decoration: InputDecoration(
                                            hintText: 'کۆدی بارکۆد بە دەست بنووسە...',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.keyboard_alt_outlined,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.1),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onSubmitted: (value) {
                                            if (value.trim().isNotEmpty) {
                                              _onSuccessScan(value.trim());
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                              ),
                            ),
                          ),

                        // Bottom Action Pill (Toggle Manual Input / Barcode Gun status)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Hardware Scanner Gun Status
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'سکانەری دەرەکی (USB/BT) چالاکە',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Manual entry button
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: Icon(
                                      _showManualField
                                          ? Icons.keyboard_hide_rounded
                                          : Icons.keyboard_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _showManualField ? 'داخستنی کیبۆرد' : 'نووسینی دەستی',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showManualField = !_showManualField;
                                      });
                                      if (_showManualField) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _manualInputFocusNode.requestFocus();
                                        });
                                      } else {
                                        _keyboardFocusNode.requestFocus();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
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
    );
  }

  Widget _buildGlassIconButton({
    IconData? icon,
    String? text,
    Color? iconColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: text != null
                ? Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? Colors.white,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(ThemeData theme, MobileScannerException error) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                size: 44,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'دەستڕاگەیشتن بە کامێرا سەرکەوتوو نەبوو',
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تکایە دڵنیابەرەوە لە پێدانی مۆڵەتی کامێرا (Camera Permission)، یان کۆدەکان بە دەست بنووسە.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('دووبارە هەوڵدانەوە'),
                  onPressed: () async {
                    try {
                      await _scannerController?.start();
                    } catch (_) {}
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
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
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 52,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'سکانەری ئامێر یان سکانەری بێسیم ئامادەیە',
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'دەتوانیت بارکۆدەکە سکان بکەیت بە ئامێری دەرەکی یان لە خوارەوە بە دەست بنووسیت.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
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
    this.borderRadius = 22.0,
    this.overlayColor = const Color(0x99000000),
    this.borderColor = const Color(0xFF2563EB),
    this.borderWidth = 4.0,
    this.cornerLength = 36.0,
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
