import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../products/utils/barcode_helper.dart';
import '../../products/views/barcode_generator_dialog.dart';
import '../models/customer.dart';
import '../providers/warehouse_provider.dart';

/// Professional QR Code generation, preview, download, and printing dialog for Customers
class CustomerQrDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerQrDialog({
    super.key,
    required this.customer,
  });

  static Future<void> show(BuildContext context, Customer customer) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CustomerQrDialog(customer: customer),
    );
  }

  @override
  ConsumerState<CustomerQrDialog> createState() => _CustomerQrDialogState();
}

class _CustomerQrDialogState extends ConsumerState<CustomerQrDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;
  bool _isCreatingOrder = false;

  String get _qrData => 'CUST-${widget.customer.id}';

  Future<Uint8List?> _captureImage() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
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
      final sanitizedName = widget.customer.name
          .replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '_')
          .trim();
      final filename = 'gardi_customer_${widget.customer.id}_$sanitizedName.png';
      final success = await downloadBarcode(bytes, filename);
      if (mounted) {
        if (success) {
          AppSnackbar.show(
            context,
            message: 'وێنەی کیو ئاڕ کۆد بە سەرکەوتوویی دابەزی',
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

  Future<void> _handlePrint() async {
    final bytes = await _captureImage();
    if (bytes != null) {
      await printBarcode(bytes);
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'نەتوانرا بۆ چاپکردن ئامادە بکرێت',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _handleCopyCode() {
    Clipboard.setData(ClipboardData(text: _qrData));
    AppSnackbar.show(
      context,
      message: 'کۆدی کڕیار کۆپیکرا: $_qrData',
      type: SnackbarType.info,
    );
  }

  Future<void> _handleCreateOrder() async {
    setState(() => _isCreatingOrder = true);
    try {
      final warehouses = await ref.read(warehouseListProvider.future);
      final currentUser = ref.read(authProvider).user;
      final targetWarehouse = warehouses.isNotEmpty
          ? (currentUser?.isSalesman == true && currentUser?.warehouseId != null
              ? warehouses.where((w) => w.id == currentUser!.warehouseId).firstOrNull ??
                  warehouses.firstWhere((w) => w.isMain, orElse: () => warehouses.first)
              : warehouses.firstWhere((w) => w.isMain, orElse: () => warehouses.first))
          : null;

      final payload = {
        'customer_id': widget.customer.id,
        'warehouse_id': targetWarehouse?.id ?? 1,
        'status': 'PACKING',
        'discount_type': 'FIXED',
        'discount_percent': 0.0,
        'discount_amount': 0.0,
        'shared_key': 'order_${DateTime.now().microsecondsSinceEpoch}',
        'version': 1,
        'notes': null,
        'items': [],
      };

      final createdOrder =
          await ref.read(orderActionsProvider).createOrder(payload);

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(
          context,
          message: 'پسوڵە بۆ "${widget.customer.name}" دروستکرا، کاڵاکان زیادبکە',
          type: SnackbarType.success,
        );
        context.push('/salesman/create-order', extra: createdOrder);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'هەڵە لە دروستکردنی پسوڵە: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final customer = widget.customer;
    final currentUser = ref.watch(authProvider).user;
    final canCreateOrder = currentUser?.isSalesman == true ||
        currentUser?.isAdmin == true ||
        currentUser?.isOwner == true;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                        'کیو ئاڕ کۆدی کڕیار',
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

              // Printable / Downloadable Card Badge
              RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Logo & GARDI ERP Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'GARDI ERP',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                'سیستەمی بەڕێوەبردنی فرۆشتن',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'KJino',
                                ),
                              ),
                            ],
                          ),
                          const GardiLogoWidget(
                            width: 50,
                            height: 42,
                            color: Color(0xFF1E293B),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 22, thickness: 1.2),

                      // Customer Details
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'KJino',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customer.customerName != null &&
                                customer.customerName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'خاوەن: ${customer.customerName}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'KJino',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (customer.phone != null &&
                                    customer.phone!.isNotEmpty)
                                  Text(
                                    customer.phone!,
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (customer.route != null)
                                  Text(
                                    customer.route!.name,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontFamily: 'KJino',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // High Contrast QR Code
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        ),
                        child: QrImageView(
                          data: _qrData,
                          version: QrVersions.auto,
                          size: 190.0,
                          backgroundColor: Colors.white,
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
                      const SizedBox(height: 10),

                      // Customer Code under QR
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _qrData,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'بۆ خوێندنەوەی خێرا لەلایەن مەندوبەوە بە کامێرا',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontFamily: 'KJino',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons Row: Download & Print & Copy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleCopyCode,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('کۆپی کۆد'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isCapturing ? null : _handlePrint,
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('چاپکردن'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Main Download Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isCapturing ? null : _handleDownload,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isCapturing ? 'خەریکی ئامادەکردنە...' : 'داگرتنی وێنەی کیو ئاڕ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // Direct "Create Order" button if user can create order
              if (canCreateOrder) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _isCreatingOrder ? null : _handleCreateOrder,
                  icon: _isCreatingOrder
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: Text(
                    _isCreatingOrder
                        ? 'خەریکی دروستکردنی پسوڵەیە...'
                        : 'دروستکردنی ڕاستەوخۆی پسوڵە بۆ ئەم کڕیارە',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
