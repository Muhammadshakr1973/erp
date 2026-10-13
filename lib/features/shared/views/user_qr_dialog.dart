import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_model.dart';
import '../../products/utils/barcode_helper.dart';

/// Professional QR Code generation, preview, and direct download dialog for System Users
/// Renders standard 50mm x 30mm thermal printable label:
/// Left: QR Code
/// Right: User Name, User Role (مەندوب، شۆفێر، کارمەندی کۆگا...), and Phone Number
class UserQrDialog extends StatefulWidget {
  final String barcode;
  final String userName;
  final String userRole;
  final String userPhone;
  final UserModel? user;

  const UserQrDialog({
    super.key,
    required this.barcode,
    required this.userName,
    required this.userRole,
    required this.userPhone,
    this.user,
  });

  static Future<void> show(
    BuildContext context, {
    required String barcode,
    required String userName,
    required String userRole,
    required String userPhone,
    UserModel? user,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => UserQrDialog(
        barcode: barcode,
        userName: userName,
        userRole: userRole,
        userPhone: userPhone,
        user: user,
      ),
    );
  }

  @override
  State<UserQrDialog> createState() => _UserQrDialogState();
}

class _UserQrDialogState extends State<UserQrDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

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
      debugPrint('Error capturing user QR image: $e');
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
      final safeUserName = widget.userName
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^\w\-\u0600-\u06FF]'), '')
          .trim();
      final filename =
          'gardi_user_${widget.barcode}${safeUserName.isNotEmpty ? '_$safeUserName' : ''}.png';
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

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.barcode));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: 'کۆدی چوونەژوورەوە کۆپیکرا',
      type: SnackbarType.success,
    );
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

    final displayName = widget.userName.trim().isNotEmpty
        ? widget.userName.trim()
        : '—';
    final displayRole = widget.userRole.trim().isNotEmpty
        ? widget.userRole.trim()
        : 'کارمەند';
    final displayPhone = widget.userPhone.trim().isNotEmpty
        ? widget.userPhone.trim()
        : '—';

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
                      const Text(
                        'کیو ئاڕ کۆدی بەکارهێنەر',
                        style: AppTextStyles.h2,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // The Exact Printable 50 × 30 mm Sticker Canvas (500px × 300px)
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
                                  data: widget.barcode,
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

                            // ----------------- RIGHT: USER INFO -----------------
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // ١- ناوی بەکارهێنەر
                                  _buildInfoBlock(
                                    label: 'ناوی بەکارهێنەر',
                                    value: displayName,
                                    isPrimary: true,
                                  ),

                                  // ٢- جۆری بەکارهێنەر (مەندوب، شۆفێر، کارمەندی کۆگا...)
                                  _buildInfoBlock(
                                    label: 'جۆری بەکارهێنەر',
                                    value: displayRole,
                                  ),

                                  // ٣- ژمارەی مۆبایل
                                  _buildInfoBlock(
                                    label: 'ژمارەی مۆبایل',
                                    value: displayPhone,
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

              // Barcode display & copy box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.barcode,
                        style: const TextStyle(
                          fontFamily: 'KJino',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: _handleCopy,
                      color: AppColors.primary,
                      tooltip: 'کۆپیکردنی کۆدەکە',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

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
