import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/product_model.dart';
import '../utils/barcode_helper.dart';

class BarcodeGeneratorDialog extends StatefulWidget {
  final ProductModel? product;
  final String? initialBarcode;

  const BarcodeGeneratorDialog({
    super.key,
    this.product,
    this.initialBarcode,
  });

  @override
  State<BarcodeGeneratorDialog> createState() => _BarcodeGeneratorDialogState();
}

class _BarcodeGeneratorDialogState extends State<BarcodeGeneratorDialog> {
  final TextEditingController _barcodeController = TextEditingController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _barcodeController.text = widget.product?.barcode ?? widget.initialBarcode ?? '202619001';
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureImage() async {
    setState(() => _isCapturing = true);
    // Give a short frame delay to ensure UI updates before capturing
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing barcode image: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _handleDownload() async {
    final bytes = await _captureImage();
    if (bytes != null) {
      final name = widget.product?.name ?? 'barcode';
      final cleanedName = name.replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '_');
      downloadBarcode(bytes, 'gardi_barcode_${cleanedName}_${_barcodeController.text}.png');
      _showSnackbar('وێنەکە بە سەرکەوتوویی دابەزی');
    } else {
      _showSnackbar('کێشەیەک لە دروستکردنی وێنەکە ڕوویدا', isError: true);
    }
  }

  void _handlePrint() async {
    final bytes = await _captureImage();
    if (bytes != null) {
      printBarcode(bytes);
    } else {
      _showSnackbar('کێشەیەک لە ئامادەکردنی فایلی چاپکردن ڕوویدا', isError: true);
    }
  }

  void _handleShare() {
    final text = _barcodeController.text;
    Clipboard.setData(ClipboardData(text: text));
    _showSnackbar('بارکۆدی "$text" کۆپیکرا بۆ Clipboard بۆ شەیرکردن');
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barcodeText = _barcodeController.text.trim().toUpperCase();

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('دروستکەری بارکۆد', style: AppTextStyles.h2),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Product contextual banner if loaded
              if (widget.product != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product!.name,
                              style: AppTextStyles.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'کۆمپانیا: ${widget.product!.supplier?['name'] ?? '-'} | جۆر: ${widget.product!.category?['name'] ?? '-'}',
                              style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Barcode Input
              AppTextField(
                controller: _barcodeController,
                hintText: 'کۆدی بارکۆد بنووسە...',
                labelText: 'کۆدی بارکۆد (تەنها پیت و ژمارە)',
                prefixIcon: Icons.qr_code,
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Printable label preview
              Text(
                'پێشبینینی لایبڵ (Print/Download Asset):',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),

              // RepaintBoundary wrapping the generated printable asset
              RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white, // Barcodes must always have high-contrast white background
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label Brand Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'GARDI ERP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF122D5A),
                              letterSpacing: 1.2,
                              fontFamily: 'Rudaw',
                            ),
                          ),
                          Text(
                            widget.product != null ? 'لایبڵی کاڵا' : 'بارکۆدی دەستکرد',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              fontFamily: 'Rudaw',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.grey, height: 1, thickness: 0.8),
                      const SizedBox(height: 16),

                      // Product info on the label
                      if (widget.product != null) ...[
                        Text(
                          widget.product!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Rudaw',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (widget.product!.unit != null)
                          Text(
                            'یەکە: ${widget.product!.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontFamily: 'Rudaw',
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Barcode and QR code layout
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 1D Barcode Column
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 90,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: Code39Painter(
                                      data: barcodeText,
                                      barColor: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  barcodeText.isEmpty ? '---' : barcodeText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3.0,
                                    color: Colors.black,
                                    fontFamily: 'Rudaw',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // QR Code Column
                          if (barcodeText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: QrImageView(
                                data: barcodeText,
                                version: QrVersions.auto,
                                size: 100,
                                gapless: false,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons Row
              Row(
                children: [
                  // Print
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isCapturing ? null : _handlePrint,
                      icon: const Icon(Icons.print, size: 20),
                      label: const Text(
                        'پرێنتکردن',
                        style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Download
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isCapturing ? null : _handleDownload,
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text(
                        'وێنە دابەزێنە',
                        style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Copy/Share button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceContainerDark : Colors.grey.shade100,
                  foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isCapturing ? null : _handleShare,
                icon: const Icon(Icons.share, size: 18),
                label: const Text(
                  'شەیرکردن / کۆپیکردنی کۆد',
                  style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Code39Painter extends CustomPainter {
  final String data;
  final Color barColor;

  Code39Painter({
    required this.data,
    this.barColor = Colors.black,
  });

  // Wikipedia verified character map for Code 39
  static const Map<String, String> _code39Map = {
    '0': 'NNNWNWWNN',
    '1': 'WNNNWNNWN',
    '2': 'NWNNWNNWN',
    '3': 'WWNNWNNNN',
    '4': 'NNWNWNNWN',
    '5': 'WNWNWNNNN',
    '6': 'NWWNWNNNN',
    '7': 'NNNWWNWNN',
    '8': 'WNNWWNNNN',
    '9': 'NWNWWNNNN',
    'A': 'WNNNNWNWN',
    'B': 'NWNNNWNWN',
    'C': 'WWNNNWNNN',
    'D': 'NNWNNWNWN',
    'E': 'WNWNNWNNN',
    'F': 'NWWNNWNNN',
    'G': 'NNNWNWNWN',
    'H': 'WNNWNWNNN',
    'I': 'NWNWNWNNN',
    'J': 'NNWWNWNNN',
    'K': 'WNNNNNWWN',
    'L': 'NWNNNNWWN',
    'M': 'WWNNNNWNN',
    'N': 'NNWNNNWWN',
    'O': 'WNWNNNWNN',
    'P': 'NWWNNNWNN',
    'Q': 'NNNWNNWWN',
    'R': 'WNNWNNWNN',
    'S': 'NWNWNNWNN',
    'T': 'NNWWNNWNN',
    'U': 'WNNNNNNWW',
    'V': 'NWNNNNNWW',
    'W': 'WWNNNNNWN',
    'X': 'NNWNNNNWW',
    'Y': 'WNWNNNNWN',
    'Z': 'NWWNNNNWN',
    '-': 'NWNNNNWNW',
    '.': 'WWNNNNWNN',
    ' ': 'NWWNNNWNN',
    '*': 'NNWNWWNNN',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    // Standard Code 39 contains start and stop asterisks (*)
    String fullData = data;
    if (!fullData.startsWith('*')) {
      fullData = '*$fullData';
    }
    if (!fullData.endsWith('*')) {
      fullData = '$fullData*';
    }

    // Build the list of elements: true for bar, false for space
    final List<_BarcodeElement> elements = [];

    for (int i = 0; i < fullData.length; i++) {
      final char = fullData[i];
      final pattern = _code39Map[char] ?? _code39Map[' ']!; // Fallback to space

      for (int p = 0; p < pattern.length; p++) {
        final isBar = (p % 2 == 0); // Even index is Bar, odd is Space
        final isWide = (pattern[p] == 'W');
        elements.add(_BarcodeElement(isBar, isWide));
      }

      // Add inter-character gap (narrow space) except for the very last character
      if (i < fullData.length - 1) {
        elements.add(_BarcodeElement(false, false));
      }
    }

    // Calculate total module units to scale the barcode perfectly
    // Wide module = 3.0, Narrow module = 1.0
    double totalUnits = 0.0;
    for (var element in elements) {
      totalUnits += element.isWide ? 3.0 : 1.0;
    }

    // Determine the scaling factors
    final unitWidth = size.width / totalUnits;

    double currentX = 0.0;
    for (var element in elements) {
      final width = (element.isWide ? 3.0 : 1.0) * unitWidth;

      if (element.isBar) {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, width, size.height),
          paint,
        );
      }

      currentX += width;
    }
  }

  @override
  void build(covariant CustomPainter oldDelegate) => true;

  @override
  bool shouldRepaint(covariant Code39Painter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.barColor != barColor;
  }
}

class _BarcodeElement {
  final bool isBar;
  final bool isWide;

  _BarcodeElement(this.isBar, this.isWide);
}
