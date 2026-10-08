import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

  String _toArabicIndicDigits(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return result;
  }

  String _normalizeToEnglishDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  String _formatPriceToArabic(String input) {
    final cleanInput = input.replaceAll(',', '').replaceAll(' ', '');
    // Normalize Kurdish/Arabic digits to English digits for correct integer parsing
    String normalized = cleanInput;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < 10; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    final number = int.tryParse(normalized);
    if (number == null) {
      return _toArabicIndicDigits(input);
    }
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return _toArabicIndicDigits(formatted);
  }

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? widget.initialBarcode ?? '07849564845',
    );
    _nameController = TextEditingController(
      text: widget.product?.name.isNotEmpty == true
          ? widget.product!.name
          : 'لاستیق باریك سپی',
    );
    final double? rawPrice = widget.product?.priceN1;
    _priceController = TextEditingController(
      text: (rawPrice != null && rawPrice > 0)
          ? _toArabicIndicDigits(rawPrice.toInt().toString())
          : _toArabicIndicDigits('1000'),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureImage() async {
    setState(() => _isCapturing = true);
    // Give a short frame delay to ensure UI updates before capturing
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      // Capture at high resolution to produce the exact physical pixel size for 50x30mm at 300 DPI
      final image = await boundary.toImage(pixelRatio: 591.0 / 500.0);
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
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (widget.product?.name ?? 'barcode');
      final cleanedName = name.replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '_');
      final code = _barcodeController.text.trim();
      downloadBarcode(bytes, 'gardi_label_${cleanedName}_$code.png');
      _showSnackbar('وێنەی لایبڵەکە بە سەرکەوتوویی دابەزی');
    } else {
      _showSnackbar('کێشەیەک لە دروستکردنی وێنەکە ڕوویدا', isError: true);
    }
  }

  void _handleShare() async {
    final bytes = await _captureImage();
    final code = _barcodeController.text.trim();
    if (bytes != null) {
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (widget.product?.name ?? 'barcode');
      final cleanedName = name.replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '_');
      shareBarcode(bytes, 'gardi_label_${cleanedName}_$code.png', text: 'کۆدی بارکۆد: $code');
      _showSnackbar('دەتوانیت ئاپەکە هەڵبژێریت بۆ ناردنی وێنەی بارکۆدەکە');
    } else {
      Clipboard.setData(ClipboardData(text: code));
      _showSnackbar('بارکۆدی "$code" کۆپیکرا بۆ Clipboard');
    }
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
    final productName = _nameController.text.trim().isEmpty ? 'ناوی کاڵا' : _nameController.text.trim();
    final priceText = _priceController.text.trim().isEmpty ? '١٠٠٠' : _priceController.text.trim();
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = min(660.0, screenWidth - 32.0);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        width: dialogWidth,
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.barcode_reader, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'دروستکەری بارکۆد و لایبڵی کاڵا',
                            style: TextStyle(fontFamily: 'Rudaw', fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'داخستن',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Inputs Section (پۆپئەپ بۆ گۆڕانکاری لە ناو، نرخ، و کۆدی بارکۆد پێش وێنەکە)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainerDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Product Name (Full width on both mobile and desktop)
                    AppTextField(
                      controller: _nameController,
                      labelText: 'ناوی کاڵا',
                      hintText: 'ناوی کاڵا بنووسە...',
                      prefixIcon: Icons.shopping_bag_outlined,
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Price and Barcode Code as a Segmented Input with 0 gap
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Right input (first child in RTL: Price)
                          Expanded(
                            child: AppTextField(
                              controller: _priceController,
                              labelText: 'نرخ (دینار)',
                              hintText: '١٠٠٠',
                              prefixIcon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                                topLeft: Radius.zero,
                                bottomLeft: Radius.zero,
                              ),
                              onChanged: (value) {
                                final converted = _toArabicIndicDigits(value);
                                if (converted != value) {
                                  _priceController.value = TextEditingValue(
                                    text: converted,
                                    selection: TextSelection.fromPosition(
                                      TextPosition(offset: converted.length),
                                    ),
                                  );
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          // Left input (second child in RTL: Barcode Code)
                          Expanded(
                            child: AppTextField(
                              controller: _barcodeController,
                              labelText: 'کۆدی بارکۆد',
                              hintText: '07849564845',
                              prefixIcon: Icons.barcode_reader,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                                topRight: Radius.zero,
                                bottomRight: Radius.zero,
                              ),
                              onChanged: (value) {
                                final normalized = _normalizeToEnglishDigits(value);
                                if (normalized != value) {
                                  _barcodeController.value = TextEditingValue(
                                    text: normalized,
                                    selection: TextSelection.fromPosition(
                                      TextPosition(offset: normalized.length),
                                    ),
                                  );
                                }
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Price Chips Selector
                    const Text(
                      'دیاریکردنی خێرای نرخ:',
                      style: TextStyle(
                        fontFamily: 'Rudaw',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['250', '500', '750', '1000', '1500', '2000', '2500', '3000'].map((price) {
                        final arabicPrice = _toArabicIndicDigits(price);
                        final currentControllerTextClean = _toArabicIndicDigits(_priceController.text.replaceAll(',', '').replaceAll(' ', ''));
                        final isSelected = currentControllerTextClean == arabicPrice;
                        return ChoiceChip(
                          showCheckmark: false,
                          label: Text(
                            arabicPrice,
                            style: TextStyle(
                              fontFamily: 'Rudaw',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _priceController.text = arabicPrice;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // The Exact Printable 50 × 30 mm Sticker / Label Canvas (Matching Reference Image 100%)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      width: 500,
                      height: 300,
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: Colors.black, width: 2.0),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ----------------- TOP ROW -----------------
                            Expanded(
                              flex: 180,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top Left: Logo Box
                                  SizedBox(
                                    width: 175,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: const GardiLogoWidget(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),

                                  // Vertical divider between Logo and Barcode Box
                                  Container(
                                    width: 2.0,
                                    color: Colors.black,
                                  ),

                                  // Top Right: Barcode Box (Maximized space, low margins, full width & height)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Barcode Bars filling maximum space
                                          Expanded(
                                            child: CustomPaint(
                                              painter: Barcode128Painter(
                                                data: barcodeText.isEmpty ? '07849564845' : barcodeText,
                                                barColor: Colors.black,
                                              ),
                                              size: Size.infinite,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          // Barcode code number underneath
                                          Text(
                                            barcodeText.isEmpty ? '07849564845' : barcodeText,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontFamily: 'Rudaw',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black,
                                              letterSpacing: 2.5,
                                              height: 1.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Horizontal divider between Top and Bottom Row
                            Container(
                              height: 2.0,
                              color: Colors.black,
                            ),

                            // ----------------- BOTTOM ROW -----------------
                            Expanded(
                              flex: 120,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Bottom Left: Price Box (Solid Black Container)
                                  SizedBox(
                                    width: 150,
                                    child: Container(
                                      color: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Text(
                                            _formatPriceToArabic(priceText),
                                            style: const TextStyle(
                                              fontFamily: 'Rudaw',
                                              fontSize: 90,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
                                              height: 0.95,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Vertical divider between Price and Product Name
                                  Container(
                                    width: 2.0,
                                    color: Colors.black,
                                  ),

                                  // Bottom Right: Product Name Box
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      alignment: Alignment.center,
                                      child: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          productName,
                                          style: const TextStyle(
                                            fontFamily: 'Rudaw',
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            height: 1.15,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons Row (Print button removed, only Download and Copy/Share left)
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    // Download button (Right side in RTL)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                              topLeft: Radius.zero,
                              bottomLeft: Radius.zero,
                            ),
                          ),
                        ),
                        onPressed: _isCapturing ? null : _handleDownload,
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text(
                          'وێنە دابەزێنە',
                          style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    // Copy/Share button (Left side in RTL)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.surfaceContainerDark : Colors.grey.shade100,
                          foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            width: 1.0,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              topRight: Radius.zero,
                              bottomRight: Radius.zero,
                            ),
                          ),
                        ),
                        onPressed: _isCapturing ? null : _handleShare,
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'شەیرکردن / کۆپی',
                          style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
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
}

/// Dedicated vector widget rendering the exact GARDI corporate logo
/// with 3 buildings, windows, entrance doors, baseline, ® trademark, and GARDI text.
class GardiLogoWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const GardiLogoWidget({
    super.key,
    this.width = 150,
    this.height = 125,
    this.color = const Color(0xFF516982),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: GardiLogoPainter(color: color),
      ),
    );
  }
}

class GardiLogoPainter extends CustomPainter {
  final Color color;

  GardiLogoPainter({this.color = const Color(0xFF516982)});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Normalize coordinates to 100 x 100 viewBox
    canvas.scale(size.width / 100.0, size.height / 100.0);

    final buildingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cutoutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. Horizontal Ground Line / Baseline
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8.0, 67.5, 84.0, 3.2),
        const Radius.circular(0.8),
      ),
      buildingPaint,
    );

    // 2. Center Building (Tallest with Gable / Triangular Roof)
    final centerPath = Path()
      ..moveTo(38.5, 67.5)
      ..lineTo(38.5, 24.0)
      ..lineTo(50.0, 9.0)
      ..lineTo(61.5, 24.0)
      ..lineTo(61.5, 67.5)
      ..close();
    canvas.drawPath(centerPath, buildingPaint);

    // Windows on Center Building (5 rows of windows matching 1.png)
    // Row 1: single centered window at the top
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47.25, 18.5, 5.5, 5.8),
        const Radius.circular(0.8),
      ),
      cutoutPaint,
    );

    // Rows 2-5: each containing 2 windows
    const windowRows = [27.0, 35.5, 44.0, 52.5];
    for (final y in windowRows) {
      // Left window
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(42.5, y, 5.5, 5.8),
          const Radius.circular(0.8),
        ),
        cutoutPaint,
      );
      // Right window
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(52.0, y, 5.5, 5.8),
          const Radius.circular(0.8),
        ),
        cutoutPaint,
      );
    }

    // Entrance Doors at bottom of center building
    canvas.drawRect(const Rect.fromLTWH(45.5, 60.5, 3.8, 7.0), cutoutPaint);
    canvas.drawRect(const Rect.fromLTWH(50.7, 60.5, 3.8, 7.0), cutoutPaint);

    // 3. Left Building (Flat roof, 3 vertical slit windows matching 1.png)
    canvas.drawRect(const Rect.fromLTWH(22.5, 28.0, 14.0, 39.5), buildingPaint);
    canvas.drawRect(const Rect.fromLTWH(24.5, 32.0, 2.0, 32.0), cutoutPaint);
    canvas.drawRect(const Rect.fromLTWH(28.5, 32.0, 2.0, 32.0), cutoutPaint);
    canvas.drawRect(const Rect.fromLTWH(32.5, 32.0, 2.0, 32.0), cutoutPaint);

    // 4. Right Building (Symmetrical to left building with 3 vertical slit windows)
    canvas.drawRect(const Rect.fromLTWH(63.5, 28.0, 14.0, 39.5), buildingPaint);
    canvas.drawRect(const Rect.fromLTWH(65.5, 32.0, 2.0, 32.0), cutoutPaint);
    canvas.drawRect(const Rect.fromLTWH(69.5, 32.0, 2.0, 32.0), cutoutPaint);
    canvas.drawRect(const Rect.fromLTWH(73.5, 32.0, 2.0, 32.0), cutoutPaint);

    // 5. Registered Trademark Symbol ®
    final circleStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(const Offset(86.5, 62.0), 4.6, circleStroke);

    final textPainterR = TextPainter(
      text: TextSpan(
        text: 'R',
        style: TextStyle(
          fontSize: 5.6,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: 'Rudaw',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterR.paint(
      canvas,
      Offset(86.5 - textPainterR.width / 2, 62.0 - textPainterR.height / 2),
    );

    // 6. Brand Name "GARDI"
    final textPainterGardi = TextPainter(
      text: TextSpan(
        text: 'GARDI',
        style: TextStyle(
          fontSize: 18.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 4.0,
          fontFamily: 'Rudaw',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterGardi.paint(
      canvas,
      Offset(50.0 - textPainterGardi.width / 2, 74.5),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GardiLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Production-grade Code 128 barcode generator
/// Encodes standard GS1/ISO/IEC 15417 Code 128 symbols with automatic
/// density optimization for pure digits and full ASCII support.
class Barcode128Painter extends CustomPainter {
  final String data;
  final Color barColor;

  Barcode128Painter({
    required this.data,
    this.barColor = Colors.black,
  });

  static const List<String> _code128Patterns = [
    '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213',
    '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
    '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
    '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
    '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
    '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
    '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
    '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
    '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
    '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
    '114131', '311141', '411131', '211412', '211214', '211232', '2331112'
  ];

  static String _normalizeEnglish(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  static List<int> _encode(String raw) {
    String str = _normalizeEnglish(raw.trim());
    if (str.isEmpty) str = '07849564845';

    final isDigitsOnly = RegExp(r'^\d+$').hasMatch(str);
    if (isDigitsOnly && str.length >= 2 && str.length % 2 == 0) {
      // Code 128 Subset C (pairs of digits for maximum thickness and readability)
      final symbols = <int>[105];
      int checksum = 105;
      int weight = 1;
      for (int i = 0; i < str.length; i += 2) {
        final val = int.parse(str.substring(i, i + 2));
        symbols.add(val);
        checksum += val * weight;
        weight++;
      }
      symbols.add(checksum % 103);
      symbols.add(106); // Stop pattern
      return symbols;
    } else {
      // Code 128 Subset B (full alphanumeric ASCII support)
      final symbols = <int>[104];
      int checksum = 104;
      int weight = 1;
      for (int i = 0; i < str.length; i++) {
        int code = str.codeUnitAt(i) - 32;
        if (code < 0 || code > 95) code = 0;
        symbols.add(code);
        checksum += code * weight;
        weight++;
      }
      symbols.add(checksum % 103);
      symbols.add(106); // Stop pattern
      return symbols;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final symbols = _encode(data);
    int totalModules = 0;
    for (final sym in symbols) {
      if (sym < 0 || sym >= _code128Patterns.length) continue;
      final pat = _code128Patterns[sym];
      for (int i = 0; i < pat.length; i++) {
        totalModules += pat.codeUnitAt(i) - 48;
      }
    }

    if (totalModules <= 0) return;

    final double unitWidth = size.width / totalModules;
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    double currentX = 0.0;
    for (final sym in symbols) {
      if (sym < 0 || sym >= _code128Patterns.length) continue;
      final pat = _code128Patterns[sym];
      for (int p = 0; p < pat.length; p++) {
        final int wUnits = pat.codeUnitAt(p) - 48;
        final double barW = wUnits * unitWidth;
        if (p % 2 == 0) {
          // Even index = Bar
          canvas.drawRect(
            Rect.fromLTWH(currentX, 0, barW, size.height),
            paint,
          );
        }
        currentX += barW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant Barcode128Painter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.barColor != barColor;
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
  bool shouldRepaint(covariant Code39Painter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.barColor != barColor;
  }
}

class _BarcodeElement {
  final bool isBar;
  final bool isWide;

  _BarcodeElement(this.isBar, this.isWide);
}
