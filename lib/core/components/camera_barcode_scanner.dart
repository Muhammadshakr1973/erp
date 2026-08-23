import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class CameraBarcodeScanner extends StatefulWidget {
  final Function(String barcode) onScan;

  const CameraBarcodeScanner({super.key, required this.onScan});

  static Future<void> show(BuildContext context, Function(String) onScan) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 480,
          height: 520,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: CameraBarcodeScanner(onScan: onScan),
        ),
      ),
    );
  }

  @override
  State<CameraBarcodeScanner> createState() => _CameraBarcodeScannerState();
}

class _CameraBarcodeScannerState extends State<CameraBarcodeScanner> with SingleTickerProviderStateMixin {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  Timer? _scanTimer;
  bool _isCameraActive = false;
  bool _hasError = false;
  String _errorMessage = '';
  late AnimationController _laserController;
  final TextEditingController _manualController = TextEditingController();

  final String _viewId = 'camera-video-view-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    _laserController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      setState(() {
        _hasError = true;
        _errorMessage = 'کامێرا تەنها لەسەر وێب بەردەستە لەم وەشانەدا.';
      });
      return;
    }

    try {
      final constraints = {
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        },
        'audio': false
      };

      final stream = await html.window.navigator.mediaDevices.getUserMedia(constraints);
      _mediaStream = stream;

      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = stream;

      _videoElement!.setAttribute('playsinline', 'true');

      // Register view factory dynamically
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      setState(() {
        _isCameraActive = true;
        _hasError = false;
      });

      _startScanning();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'کێشە لە چالاککردنی کامێرا هەیە. تکایە ڕێگەپێدان پشتڕاست بکەرەوە.';
      });
    }
  }

  void _stopCamera() {
    _scanTimer?.cancel();
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getTracks()) {
        track.stop();
      }
    }
    _videoElement?.pause();
    _videoElement?.srcObject = null;
  }

  void _startScanning() {
    final barcodeDetectorClass = js_util.getProperty(html.window, 'BarcodeDetector');
    if (barcodeDetectorClass == null) {
      debugPrint('BarcodeDetector is not supported in this browser.');
      return;
    }

    final detector = js_util.callConstructor(barcodeDetectorClass, [
      js_util.jsify({
        'formats': ['code_128', 'ean_13', 'ean_8', 'qr_code', 'code_39', 'upc_a', 'upc_e']
      })
    ]);

    _scanTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (_videoElement == null || !_isCameraActive) return;

      try {
        final List results = await js_util.promiseToFuture(
          js_util.callMethod(detector, 'detect', [_videoElement])
        );

        if (results.isNotEmpty) {
          final firstResult = results.first;
          final String barcode = js_util.getProperty(firstResult, 'rawValue');
          if (barcode.isNotEmpty) {
            _onSuccessScan(barcode);
          }
        }
      } catch (e) {
        // Silent catch for frame read errors
      }
    });
  }

  void _onSuccessScan(String barcode) {
    _stopCamera();
    widget.onScan(barcode);
    Navigator.of(context).pop();

    // Show quick feedback snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'بارکۆد بە سەرکەوتوویی خوێندرایەوە: $barcode',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'خوێنەرەوەی بارکۆد',
                      style: AppTextStyles.h2.copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Camera Viewfinder / Fallback
          Expanded(
            child: Stack(
              children: [
                if (_isCameraActive && !_hasError)
                  HtmlElementView(viewType: _viewId)
                else
                  Container(
                    color: Colors.black.withOpacity(0.05),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hasError ? Icons.videocam_off_outlined : Icons.photo_camera_back_outlined,
                          size: 64,
                          color: _hasError ? AppColors.danger : theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasError ? _errorMessage : 'سەرچاوەی کامێرا ئامادە دەکرێت...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _hasError ? AppColors.danger : theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // Viewfinder lines & Laser Animation (Only when active)
                if (_isCameraActive && !_hasError) ...[
                  // Semi-transparent overlay to focus attention
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 200,
                            width: 320,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bounding Box outline & Red Laser
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 200,
                      width: 320,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Bounding box corners styling
                          AnimatedBuilder(
                            animation: _laserController,
                            builder: (context, child) {
                              return Positioned(
                                top: _laserController.value * 200,
                                left: 10,
                                right: 10,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.8),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
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
                ],
              ],
            ),
          ),

          // Footer Actions / Manual Input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'کۆدی بارکۆد بە دەستی بنووسە...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
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
                        if (_manualController.text.trim().isNotEmpty) {
                          _onSuccessScan(_manualController.text.trim());
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'تێبینی: ئەگەر کامێرا کار ناکات، دەتوانیت لێرە بارکۆدەکە بنووسیت.',
                  style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
