import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
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
          height: 600,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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

class _CameraBarcodeScannerState extends State<CameraBarcodeScanner> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime? _lastKeyEventTime;
  bool _isProcessing = false;
  
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _keyboardFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onSuccessScan(String barcode) {
    if (_isProcessing) return;
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
    });

    widget.onScan(cleanBarcode);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'بارکۆد بە سەرکەوتوویی خوێندرایەوە: $cleanBarcode',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'خوێندنەوەی بارکۆد',
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

            // Camera Scanner & Instruction
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _onSuccessScan(barcode.rawValue!);
                          break; // Only scan one
                        }
                      }
                    },
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: Colors.black.withValues(alpha: 0.05),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_outlined,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'کامێرا کارناکات، تکایە ئامێری سکانەر بەکاربهێنە یان بە دەست بینوسە.',
                              style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Overlay targeting box
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Manual Input Fallback & Action Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: FocusNode(), 
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'کۆدی بارکۆدەکە بە دەست بنووسە...',
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
                          if (_controller.text.trim().isNotEmpty) {
                            _onSuccessScan(_controller.text.trim());
                          }
                        },
                      ),
                    ],
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
