import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/utils/barcode_helper.dart';
// import '../../products/views/barcode_generator_dialog.dart';
import '../models/customer.dart';

/// Professional QR Code generation, preview, and direct download dialog for Customers
class CustomerQrDialog extends StatefulWidget {
  final Customer customer;

  const CustomerQrDialog({super.key, required this.customer});

  static Future<void> show(BuildContext context, Customer customer) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CustomerQrDialog(customer: customer),
    );
  }

  @override
  State<CustomerQrDialog> createState() => _CustomerQrDialogState();
}

class _CustomerQrDialogState extends State<CustomerQrDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

  String get _qrData => 'CUST-${widget.customer.id}';

  Future<Uint8List?> _captureImage() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      // 500x300 at 2.0x generates a sharp 1000x600 px image (exact 50mm x 30mm ratio)
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing customer QR image: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _handleDownload() async {
    final bytes = await _captureImage();
    if (bytes != null) {
      final safeCustomerName = widget.customer.name
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^\w\-\u0600-\u06FF]'), '')
          .trim();
      final filename =
          'gardi_qr_${widget.customer.id}${safeCustomerName.isNotEmpty ? '_$safeCustomerName' : ''}.png';
      final success = await downloadBarcode(bytes, filename);
      if (mounted) {
        if (success) {
          AppSnackbar.show(
            context,
            message: 'وێنەی کیو ئاڕ کۆد (٥٠×٣٠ ملم) بە سەرکەوتوویی دابەزی',
            type: SnackbarType.success,
          );
        } else {
          AppSnackbar.show(
            context,
            message: 'کێشەیەک لە دابەزاندنی وێنەکەدا ڕوویدا',
            type: SnackbarType.error,
          );
        }
      }
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'کێشەیەک لە ئامادەکردنی وێنەکەدا ڕوویدا',
          type: SnackbarType.error,
        );
      }
    }
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
    bool isPrimary = false,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'KJino',
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            textDirection: isPhone ? TextDirection.ltr : null,
            style: TextStyle(
              fontFamily: isPhone ? null : 'KJino',
              fontSize: isPrimary ? 32 : 27,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.15,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final customer = widget.customer;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('کیو ئاڕ کۆدی کڕیار', style: AppTextStyles.h2),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // The Exact Printable 50 × 30 mm Sticker Canvas (1mm = 10px -> 500px × 300px)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      width: 500,
                      height: 300,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ----------------- LEFT: QR CODE -----------------
                            SizedBox(
                              width: 245,
                              height: 276,
                              child: Center(
                                child: QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  size: 245.0,
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.all(2),
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // ----------------- RIGHT: CUSTOMER INFO -----------------
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // ١- ناوی مارکێت
                                  _buildInfoBlock(
                                    label: 'ناوی مارکێت',
                                    value: customer.name.isNotEmpty
                                        ? customer.name
                                        : '—',
                                    isPrimary: true,
                                  ),

                                  // ٢- ناوی خاوەن
                                  _buildInfoBlock(
                                    label: 'ناوی خاوەن',
                                    value:
                                        (customer.customerName != null &&
                                            customer.customerName!
                                                .trim()
                                                .isNotEmpty)
                                        ? customer.customerName!
                                        : '—',
                                  ),

                                  // ٣- ژمارە مۆبایل
                                  _buildInfoBlock(
                                    label: 'ژمارە مۆبایل',
                                    value:
                                        (customer.phone != null &&
                                            customer.phone!.trim().isNotEmpty)
                                        ? customer.phone!
                                        : '—',
                                    isPhone: true,
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

              const SizedBox(height: AppSpacing.md),

              // Label Size Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.straighten_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'پێوانەی ستیکەر: ٥٠ملم پانی × ٣٠ملم بەرزی (بۆ چاپکەری حەراری)',
                      style: TextStyle(
                        fontFamily: 'KJino',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Button (دابەزاندنی وێنەی کیو ئاڕ)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isCapturing ? null : _handleDownload,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 22),
                  label: Text(
                    _isCapturing
                        ? 'خەریکی دابەزاندنە...'
                        : 'دابەزاندنی وێنەی کیو ئاڕ',
                    style: const TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
