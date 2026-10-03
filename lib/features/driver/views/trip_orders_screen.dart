import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/views/map_picker_dialog.dart';
import '../models/delivery_trip_model.dart';
import '../providers/driver_providers.dart';

class TripOrdersScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripOrdersScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripOrdersScreen> createState() => _TripOrdersScreenState();
}

class _TripOrdersScreenState extends ConsumerState<TripOrdersScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intParsedId = int.tryParse(widget.tripId) ?? 0;
    final tripDetailAsync = ref.watch(tripDetailProvider(intParsedId));

    return Scaffold(
      appBar: AppBar(
        title: Text('وردەکاری گەشت #$intParsedId', style: AppTextStyles.h2),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripDetailProvider(intParsedId));
          await ref.read(tripDetailProvider(intParsedId).future);
        },
        child: tripDetailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'کێشەیەک لە بارکردنی گەشتەکە ڕوویدا',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(err.toString(), style: AppTextStyles.caption),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(tripDetailProvider(intParsedId)),
                          child: const Text('دووبارە هەوڵبدەرەوە'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          data: (trip) {
            int total = trip.orders.length;
            int delivered = trip.orders.where((o) => o.status == 'DELIVERED').length;
            int failed = trip.orders.where((o) => o.status == 'FAILED').length;
            int pending = total - delivered - failed;
  
            final sortedOrders = List<DeliveryTripOrderModel>.from(trip.orders)..sort((a, b) {
              final routeA = _getOrderRouteName(a);
              final routeB = _getOrderRouteName(b);
              final routeComp = routeA.compareTo(routeB);
              if (routeComp != 0) return routeComp;
              return a.deliveryOrder.compareTo(b.deliveryOrder);
            });
  
            return Column(
              children: [
                _buildTripSummary(total, delivered, pending, failed),
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    itemCount: sortedOrders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final tripOrder = sortedOrders[index];
                    final order = tripOrder.order;
                    final customerName = _getCustomerName(order?.customer);
                    final isPending = tripOrder.status == 'PENDING';
                    final routeName = _getOrderRouteName(tripOrder);
                    final isDark = theme.brightness == Brightness.dark;
                    final phoneColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF);

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: AppTextStyles.bodyBold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                                        : const Color(0xFF93C5FD),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.alt_route_rounded,
                                      size: 14,
                                      color: isDark
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      routeName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF1D4ED8),
                                        fontFamily: 'Rudaw',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_getCustomerPhone(order?.customer).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: phoneColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getCustomerPhone(order?.customer),
                                    style: AppTextStyles.caption.copyWith(
                                      color: phoneColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'ناونیشان: ${_getCustomerAddress(order?.customer)}',
                                  style: AppTextStyles.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  MapPickerDialog.showCustomerLocation(
                                    context,
                                    customerName: customerName,
                                    customerAddress: _getCustomerAddress(order?.customer),
                                    latitude: _getCustomerLatitude(order?.customer),
                                    longitude: _getCustomerLongitude(order?.customer),
                                    isReadOnly: true,
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map_outlined, size: 14, color: theme.colorScheme.primary),
                                      const SizedBox(width: 2),
                                      Text(
                                        'شوێن',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Rudaw',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (tripOrder.notes != null && tripOrder.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'تێبینی: ${tripOrder.notes}',
                              style: AppTextStyles.caption.copyWith(color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (order != null && order.items.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(bottom: 8.0),
                                title: Text(
                                  'کاڵاکانی پسوڵەکە (${order.items.length} جۆر)',
                                  style: AppTextStyles.caption.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                children: order.items.map((item) => Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showProductImageFullScreen(context, item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.image_search_outlined,
                                                  size: 16,
                                                  color: theme.colorScheme.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '• ${item.productName} (${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.productUnit})',
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            '${_formatCurrency(item.subtotal)} د.ع',
                                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${_formatCurrency(order?.totalAmount ?? 0)} د.ع',
                                  style: AppTextStyles.price,
                                ),
                              ),
                              if (isPending && !_isSubmitting)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppButton(
                                      text: 'گەیشت',
                                      size: AppButtonSize.sm,
                                      type: AppButtonType.primary,
                                      onPressed: () => _showDeliverDialog(tripOrder),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    AppButton(
                                      text: 'شکست',
                                      size: AppButtonSize.sm,
                                      type: AppButtonType.danger,
                                      onPressed: () => _showFailDialog(tripOrder),
                                    ),
                                  ],
                                )
                              else if (!isPending)
                                StatusBadge(
                                  label: _getOrderStatusLabel(tripOrder.status),
                                  type: _getOrderStatusBadgeType(tripOrder.status),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  String _getCustomerName(dynamic customer) {
    if (customer == null) return 'کڕیاری نەناسراو';
    if (customer is Map) return customer['name']?.toString() ?? 'کڕیاری نەناسراو';
    return 'کڕیاری نەناسراو';
  }

  String _getOrderRouteName(DeliveryTripOrderModel tripOrder) {
    final order = tripOrder.order;
    if (order != null) {
      if (order.customer is Map) {
        final cMap = order.customer as Map;
        if (cMap['route'] is Map && cMap['route']['name'] != null) {
          final rName = cMap['route']['name'].toString().trim();
          if (rName.isNotEmpty) return rName;
        }
        if (cMap['route_name'] != null && cMap['route_name'].toString().trim().isNotEmpty) {
          final rName = cMap['route_name'].toString().trim();
          if (rName.isNotEmpty) return rName;
        }
      }
      final rName = order.customerRouteName;
      if (rName.isNotEmpty && rName != 'ڕاوت دیاری نەکراوە') {
        return rName;
      }
    }
    return 'بێ ڕاوت';
  }

  String _getCustomerPhone(dynamic customer) {
    if (customer == null) return '';
    if (customer is Map) {
      final phone = customer['phone']?.toString() ?? '';
      if (phone.isNotEmpty) return phone;
      return customer['phone2']?.toString() ?? '';
    }
    return '';
  }

  String _getCustomerAddress(dynamic customer) {
    if (customer == null) return 'ناونیشان دیاری نەکراوە';
    if (customer is Map) {
      final addr = customer['address']?.toString() ?? '';
      return addr.trim().isNotEmpty ? addr.trim() : 'ناونیشان دیاری نەکراوە';
    }
    return 'ناونیشان دیاری نەکراوە';
  }

  double? _getCustomerLatitude(dynamic customer) {
    if (customer == null) return null;
    if (customer is Map) {
      return double.tryParse(customer['latitude']?.toString() ?? '');
    }
    return null;
  }

  double? _getCustomerLongitude(dynamic customer) {
    if (customer == null) return null;
    if (customer is Map) {
      return double.tryParse(customer['longitude']?.toString() ?? '');
    }
    return null;
  }

  String _getOrderStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return 'گەیشتووە';
      case 'FAILED':
        return 'شکستی هێنا';
      default:
        return 'لە ڕێگادایە';
    }
  }

  StatusBadgeType _getOrderStatusBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return StatusBadgeType.success;
      case 'FAILED':
        return StatusBadgeType.danger;
      default:
        return StatusBadgeType.warning;
    }
  }

  Widget _buildTripSummary(int total, int delivered, int pending, int failed) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final successColor = ext?.success ?? AppColors.success;
    final warningColor = ext?.warning ?? AppColors.warning;
    final dangerColor = ext?.danger ?? AppColors.danger;

    return Container(
      color: theme.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('هەموو', '$total'),
          _buildSummaryItem('گەیشتوو', '$delivered', successColor),
          _buildSummaryItem('ماوە', '$pending', warningColor),
          _buildSummaryItem('شکست', '$failed', dangerColor),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.h2.copyWith(
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num amount) {
    return Formatters.number(amount);
  }

  Future<void> _showDeliverDialog(dynamic tripOrder) async {
    final num totalAmt = tripOrder.order?.totalAmount ?? 0;
    final amountController = TextEditingController(text: totalAmt.toInt().toString());
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'پەسەندکردنی گەیاندن',
                    style: AppTextStyles.h2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    labelText: 'بڕی پارەی وەرگیراو (د.ع)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: notesController,
                    labelText: 'تێبینییەکان (ئارەزوومەندانە)',
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                text: 'تۆمارکردن',
                type: AppButtonType.success,
                onPressed: () async {
                  final amount = int.tryParse(amountController.text) ?? 0;
                  Navigator.of(context).pop();
                  _submitDeliver(tripOrder.id, amount, notesController.text);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitDeliver(int tripOrderId, int amount, String notes) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(driverActionsProvider).deliverOrder(
            tripOrderId: tripOrderId,
            receivedAmount: amount,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'پسوڵەکە بە سەرکەوتوویی بە گەیەنراو تۆمارکرا',
          type: SnackbarType.success,
        );
      }
      ref.invalidate(tripDetailProvider(int.parse(widget.tripId)));
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'شکست لە تۆمارکردن: ${e.toString()}',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showFailDialog(dynamic tripOrder) async {
    final notesController = TextEditingController();
    String selectedReason = 'کڕیار لە شوێنەکە نەبوو';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'تۆمارکردنی شکستی گەیاندن',
                        style: AppTextStyles.h2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'کڕیار لە شوێنەکە نەبوو',
                            child: Text('کڕیار لە شوێنەکە نەبوو'),
                          ),
                          DropdownMenuItem(
                            value: 'ناونیشانی هەڵە',
                            child: Text('ناونیشانی هەڵە'),
                          ),
                          DropdownMenuItem(
                            value: 'کڕیار کاڵاکەی ڕەتکردەوە',
                            child: Text('کڕیار کاڵاکەی ڕەتکردەوە'),
                          ),
                          DropdownMenuItem(
                            value: 'کێشەی گواستنەوە',
                            child: Text('کێشەی گواستنەوە'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'هۆکاری شکست',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: notesController,
                        labelText: 'تێبینییەکان (ئارەزوومەندانە)',
                      ),
                    ],
                  ),
                ),
                actions: [
                  AppButton(
                    text: 'پەسەندکردن',
                    type: AppButtonType.danger,
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitFail(tripOrder.id, selectedReason, notesController.text);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitFail(int tripOrderId, String reason, String notes) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(driverActionsProvider).failOrder(
            tripOrderId: tripOrderId,
            failedReason: reason,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'شکستی پسوڵەکە بە سەرکەوتوویی تۆمارکرا',
          type: SnackbarType.warning,
        );
      }
      ref.invalidate(tripDetailProvider(int.parse(widget.tripId)));
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'شکست لە تۆمارکردن: ${e.toString()}',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showProductImageFullScreen(BuildContext context, dynamic item) {
    String? rawImagePath;
    try {
      rawImagePath = item.productImagePath;
    } catch (_) {}

    final bool hasImage = rawImagePath != null && rawImagePath.trim().isNotEmpty;
    final String? resolvedUrl = hasImage ? _resolveImageUrl(rawImagePath.trim()) : null;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          child: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Stack(
                children: [
                  // Image/Content viewer area
                  Center(
                    child: resolvedUrl != null
                        ? InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              resolvedUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      size: 80,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                      child: Text(
                                        item.productName ?? 'کاڵا',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Rudaw',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'وێنەی کاڵاکە بارنەبوو یان بەردەست نییە',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: 'Rudaw',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 100,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  item.productName ?? 'کاڵا',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rudaw',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'هیچ وێنەیەک بۆ ئەم کاڵایە تۆمار نەکراوە',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Rudaw',
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Top Header Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.productName ?? 'کاڵا',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rudaw',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'بڕ: ${(item.quantity ?? 0).toStringAsFixed((item.quantity ?? 0).truncateToDouble() == (item.quantity ?? 0) ? 0 : 1)} ${item.productUnit ?? 'دانە'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontFamily: 'Rudaw',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Info Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'کۆی گشتی: ${_formatCurrency(item.subtotal ?? 0)} د.ع',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rudaw',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'پڕ بە شاشە',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Rudaw',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return 'https://pos.gardi.click$cleanPath';
  }
}
