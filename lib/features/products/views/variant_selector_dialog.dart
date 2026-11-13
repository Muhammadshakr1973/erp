import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/product_model.dart';

class VariantSelectorDialog extends StatefulWidget {
  final ProductModel parentProduct;
  final List<ProductModel> variants;
  final Map<int, int> initialQuantities;
  final double Function(ProductModel variant) getPrice;
  final double Function(ProductModel variant) getAvailableStock;
  final bool enforceStockLimit;
  final String? initialQuery;

  const VariantSelectorDialog({
    super.key,
    required this.parentProduct,
    required this.variants,
    required this.initialQuantities,
    required this.getPrice,
    required this.getAvailableStock,
    this.enforceStockLimit = true,
    this.initialQuery,
  });

  static Future<Map<int, int>?> show(
    BuildContext context, {
    required ProductModel parentProduct,
    required List<ProductModel> variants,
    required Map<int, int> initialQuantities,
    required double Function(ProductModel variant) getPrice,
    required double Function(ProductModel variant) getAvailableStock,
    bool enforceStockLimit = true,
    String? initialQuery,
  }) {
    return showDialog<Map<int, int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VariantSelectorDialog(
        parentProduct: parentProduct,
        variants: variants,
        initialQuantities: initialQuantities,
        getPrice: getPrice,
        getAvailableStock: getAvailableStock,
        enforceStockLimit: enforceStockLimit,
        initialQuery: initialQuery,
      ),
    );
  }

  @override
  State<VariantSelectorDialog> createState() => _VariantSelectorDialogState();
}

class _VariantSelectorDialogState extends State<VariantSelectorDialog> {
  late final Map<int, int> _quantities;
  late final Map<int, TextEditingController> _controllers;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _quantities = {};
    _controllers = {};
    for (final v in widget.variants) {
      final qty = widget.initialQuantities[v.id] ?? 0;
      _quantities[v.id] = qty;
      _controllers[v.id] = TextEditingController(text: qty > 0 ? '$qty' : '0');
    }
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      final q = widget.initialQuery!.trim().toLowerCase();
      final matchesVariantDirectly = widget.variants.any(
        (v) =>
            v.displayVariantLabel.toLowerCase().contains(q) ||
            v.barcode.toLowerCase().contains(q) ||
            (v.sku != null && v.sku!.toLowerCase().contains(q)),
      );
      if (matchesVariantDirectly) {
        _filterQuery = q;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setQty(ProductModel variant, int targetQty) {
    final avail = widget.getAvailableStock(variant).toInt();
    int clamped = targetQty < 0 ? 0 : targetQty;
    if (widget.enforceStockLimit && clamped > avail) {
      clamped = avail < 0 ? 0 : avail;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تەنها $avail دانە لە جۆری "${variant.displayVariantLabel}" لە ستۆکدا هەیە',
            style: const TextStyle(fontFamily: 'KJino'),
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    setState(() {
      _quantities[variant.id] = clamped;
      final ctrl = _controllers[variant.id];
      if (ctrl != null && ctrl.text != '$clamped') {
        ctrl.text = '$clamped';
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final filteredVariants = _filterQuery.isEmpty
        ? widget.variants
        : widget.variants.where((v) {
            return v.displayVariantLabel.toLowerCase().contains(_filterQuery) ||
                v.name.toLowerCase().contains(_filterQuery) ||
                v.barcode.toLowerCase().contains(_filterQuery) ||
                (v.sku != null && v.sku!.toLowerCase().contains(_filterQuery));
          }).toList();

    int totalSelectedCount = 0;
    double totalSelectedAmount = 0;
    for (final v in widget.variants) {
      final q = _quantities[v.id] ?? 0;
      if (q > 0) {
        totalSelectedCount += q;
        totalSelectedAmount += q * widget.getPrice(v);
      }
    }

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 580,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with top-left close icon button
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (widget.parentProduct.imagePath != null &&
                            widget.parentProduct.imagePath!.isNotEmpty)
                        ? Image.network(
                            widget.parentProduct.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.style_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.style_outlined,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parentProduct.name,
                          style: AppTextStyles.h3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'هەڵبژاردنی جۆر / ڕەنگ (${widget.variants.length} جۆر)',
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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

              if (widget.variants.length > 5) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  onChanged: (val) => setState(() {
                    _filterQuery = val.trim().toLowerCase();
                  }),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بە ناوی جۆر یان بارکۆد...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Variant List
              Flexible(
                child: filteredVariants.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'هیچ جۆرێک نەدۆزرایەوە',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredVariants.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final variant = filteredVariants[index];
                          final avail = widget.getAvailableStock(variant);
                          final availInt = avail.toInt();
                          final price = widget.getPrice(variant);
                          final qty = _quantities[variant.id] ?? 0;
                          final isOut = widget.enforceStockLimit && availInt <= 0;
                          final isSelected = qty > 0;

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                                  : (isDark
                                      ? const Color(0xFF1F2733)
                                      : theme.colorScheme.surfaceContainerLow),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.65)
                                    : theme.colorScheme.outlineVariant,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Variant details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              variant.displayVariantLabel,
                                              style: AppTextStyles.bodyBold.copyWith(
                                                fontSize: 14,
                                                color: isOut
                                                    ? theme.colorScheme.onSurfaceVariant
                                                    : theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!variant.useParentPrice) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.info.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'نرخی تایبەت',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.info,
                                                  fontFamily: 'KJino',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            Formatters.currency(price),
                                            style: AppTextStyles.bodyBold.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isOut
                                                      ? AppColors.danger
                                                      : (availInt <= 5
                                                          ? AppColors.warning
                                                          : AppColors.success))
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isOut
                                                  ? 'نەماوە (0)'
                                                  : 'ستۆک: $availInt',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isOut
                                                    ? AppColors.danger
                                                    : (availInt <= 5
                                                        ? AppColors.warning
                                                        : AppColors.success),
                                                fontFamily: 'KJino',
                                              ),
                                            ),
                                          ),
                                          if (variant.barcode.isNotEmpty)
                                            Text(
                                              variant.barcode,
                                              style: AppTextStyles.caption.copyWith(
                                                fontFamily: 'monospace',
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Stepper Controls (- [input] +)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _StepperIconButton(
                                      icon: Icons.remove,
                                      color: AppColors.danger,
                                      enabled: qty > 0,
                                      onPressed: () => _setQty(variant, qty - 1),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 48,
                                      height: 36,
                                      child: TextField(
                                        controller: _controllers[variant.id],
                                        enabled: !isOut || qty > 0,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: AppTextStyles.bodyBold.copyWith(
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 8,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final parsed = int.tryParse(val) ?? 0;
                                          _setQty(variant, parsed);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _StepperIconButton(
                                      icon: Icons.add,
                                      color: const Color(0xFF10B981),
                                      enabled: !widget.enforceStockLimit || qty < availInt,
                                      onPressed: () => _setQty(variant, qty + 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Summary + Primary Confirm Action ONLY (No bottom Cancel/Close button per GEMINI.md)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'کۆی بڕ: $totalSelectedCount دانە',
                    style: AppTextStyles.bodyBold,
                  ),
                  Text(
                    Formatters.currency(totalSelectedAmount),
                    style: AppTextStyles.bodyBold.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'پاشەکەوتکردن لە سەبەتە',
                icon: Icons.check_circle_outline,
                isFullWidth: true,
                onPressed: () => Navigator.pop(context, Map<int, int>.from(_quantities)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _StepperIconButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 36,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade300,
          foregroundColor: enabled ? Colors.white : Colors.grey.shade500,
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
