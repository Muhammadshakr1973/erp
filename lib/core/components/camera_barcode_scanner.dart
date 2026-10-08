import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'app_snackbar.dart';

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
        final dialogWidth = isMobile ? mediaQuery.size.width * 0.94 : 500.0;
        final dialogHeight = isMobile ? mediaQuery.size.height * 0.88 : 640.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _inputFocusNode = FocusNode();
  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime? _lastKeyEventTime;
  bool _isProcessing = false;

  MobileScannerController? _scannerController;
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    try {
      _scannerController = MobileScannerController(
        // Immediate detection per frame without 250ms throttle lag
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        autoStart: true,
        // Let the camera choose the natural sensor resolution to avoid forced landscape aspect ratio clipping
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
        ],
      );
    } catch (e) {
      debugPrint("Camera scanner initialization error: $e");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller.dispose();
    _keyboardFocusNode.dispose();
    _inputFocusNode.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onSuccessScan(String barcode) {
    if (_isProcessing) return;
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    widget.onScan(cleanBarcode);
    Navigator.of(context).pop();

    AppSnackbar.show(
      context,
      message: 'بارکۆد خوێندرایەوە: $cleanBarcode',
      type: SnackbarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyEventTime != null) {
        final difference = now.difference(_lastKeyEventTime!).inMilliseconds;
        if (difference > 150) {
          // delay
        }
      }
      _lastKeyEventTime = now;

      final logicalKey = event.logicalKey;

      if (logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          final scannedCode = _barcodeBuffer.toString();
          _barcodeBuffer.clear();
          _onSuccessScan(scannedCode);
        } else if (_controller.text.trim().isNotEmpty) {
          _onSuccessScan(_controller.text.trim());
        }
      } else {
        final character = event.character;
        if (character != null && character.isNotEmpty) {
          _barcodeBuffer.write(character);
        }
      }
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
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'خوێندنەوەی بارکۆد',
                        style: AppTextStyles.h2.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'گۆڕینی کامێرا',
                        icon: const Icon(Icons.cameraswitch_outlined),
                        onPressed: () async {
                          try {
                            await _scannerController?.switchCamera();
                          } catch (_) {}
                        },
                      ),
                      IconButton(
                        tooltip: 'فلاش / تۆڕچ',
                        icon: const Icon(Icons.flash_on_outlined),
                        onPressed: () async {
                          try {
                            await _scannerController?.toggleTorch();
                          } catch (_) {}
                        },
                      ),
                      IconButton(
                        tooltip: 'داخستن',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Camera Scanner & Viewport
            Expanded(
              child: _scannerController == null
                  ? Container(
                      color: Colors.black.withValues(alpha: 0.05),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_outlined,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'سکانەری ئامێر یان بەکارهێنانی ئامێری سکانەری بێسیم ئامادەیە. تکایە بارکۆدەکە سکان بکە یان بە دەست بنووسە.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Directionality(
                      // Force LTR coordinate system for video stream and platform views
                      // to prevent horizontal clipping in RTL layouts
                      textDirection: TextDirection.ltr,
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            // Camera Video Stream (Full camera area)
                            Positioned.fill(
                              child: MobileScanner(
                                controller: _scannerController!,
                                fit: kIsWeb ? BoxFit.contain : BoxFit.cover,
                                onDetect: (capture) {
                                  final List<Barcode> barcodes = capture.barcodes;
                                  for (final barcode in barcodes) {
                                    if (barcode.rawValue != null &&
                                        barcode.rawValue!.trim().isNotEmpty) {
                                      _onSuccessScan(barcode.rawValue!);
                                      break; // Take the first recognized barcode
                                    }
                                  }
                                },
                                errorBuilder: (context, error, child) {
                                  return Container(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_outlined,
                                            size: 48,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'دەستڕاگەیشتن بە کامێرا نییە یان مۆڵەت نەدراوە.',
                                            style: AppTextStyles.h3.copyWith(
                                              color: theme.colorScheme.onSurface,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'تکایە مۆڵەتی کامێرا بدە لە وێبگەڕ/ئامێردا، یان کامێراکە بگۆڕە، یاخود ئامێری سکانەری بێسیم/دەستی بەکاربهێنە.',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            alignment: WrapAlignment.center,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                    Icons.cameraswitch,
                                                    size: 18),
                                                label: const Text('گۆڕینی کامێرا'),
                                                onPressed: () async {
                                                  try {
                                                    await _scannerController
                                                        ?.switchCamera();
                                                  } catch (_) {}
                                                },
                                              ),
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.refresh,
                                                    size: 18),
                                                label: const Text(
                                                    'دووبارە هەوڵدانەوە'),
                                                onPressed: () async {
                                                  try {
                                                    await _scannerController
                                                        ?.start();
                                                  } catch (_) {}
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Target Viewfinder Framing Box with Laser Line
                          Center(
                            child: SizedBox(
                              width: 260,
                              height: 260,
                              child: Stack(
                                children: [
                                  // Targeting Frame Border
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2.5,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  // Corner accent highlights
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                          left: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                          right: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                          left: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                          right: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 5,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomRight: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Moving animated laser line
                                  AnimatedBuilder(
                                    animation: _laserController,
                                    builder: (context, child) {
                                      return Positioned(
                                        top: 10 + (_laserController.value * 235),
                                        left: 12,
                                        right: 12,
                                        child: Container(
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.8),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Helper text instruction badge
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'بارکۆد یان QR کۆدەکە لە ناو چوارچێوەکە ڕابگرە',
                                  textDirection: TextDirection.rtl,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),

            // Manual Input Fallback & Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocusNode,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'کۆدی بارکۆدەکە بە دەست بنووسە...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
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
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        _onSuccessScan(_controller.text.trim());
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
