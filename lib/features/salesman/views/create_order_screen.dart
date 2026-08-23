import 'package:flutter/material.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_breakpoints.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  int _cartItemCount = 0;
  double _totalPrice = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پسوڵەی نوێ', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            onPressed: () {
              CameraBarcodeScanner.show(context, (scanned) {
                setState(() {
                  _cartItemCount++;
                  _totalPrice += 15000;
                });
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopOrTablet = constraints.maxWidth >= AppBreakpoints.tabletMin;

          if (isDesktopOrTablet) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildProductSelection(context),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  flex: 1,
                  child: _buildCartPanel(context),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: _buildProductSelection(context)),
                _buildMobileCartSummary(context),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductSelection(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            hintText: 'گەڕان بۆ کاڵا...',
            prefixIcon: AppIcons.search,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              return _buildProductCard(context, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () {
        setState(() {
          _cartItemCount++;
          _totalPrice += 15000;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'کاڵای ژمارە ${index + 1}',
            style: AppTextStyles.bodyBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('15,000 د.ع', style: AppTextStyles.price),
        ],
      ),
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سەبەتە', style: AppTextStyles.h2),
                Chip(
                  label: Text('$_cartItemCount کاڵا'),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cartItemCount == 0
                ? const Center(child: Text('سەبەتە بەتاڵە', style: AppTextStyles.bodyMedium))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _cartItemCount,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ناوی کاڵا', style: AppTextStyles.bodyBold),
                                Text('15,000 د.ع', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {}),
                              const Text('1', style: AppTextStyles.bodyBold),
                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {}),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('کۆی گشتی', style: AppTextStyles.bodyLarge),
                    Text('$_totalPrice د.ع', style: AppTextStyles.priceLarge),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  text: 'تەواوکردنی پسوڵە',
                  onPressed: _cartItemCount > 0 ? () {} : null,
                  size: AppButtonSize.lg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartSummary(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_cartItemCount کاڵا', style: AppTextStyles.caption),
                  Text('$_totalPrice د.ع', style: AppTextStyles.price),
                ],
              ),
            ),
            AppButton(
              text: 'بینینی سەبەتە',
              onPressed: _cartItemCount > 0 ? () {
                // Show Bottom Sheet for cart details on mobile
              } : null,
            ),
          ],
        ),
      ),
    );
  }
}
