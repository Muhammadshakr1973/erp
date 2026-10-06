import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/customer_avatar.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/providers/customer_provider.dart';

class TodayCustomersScreen extends ConsumerStatefulWidget {
  const TodayCustomersScreen({super.key});

  @override
  ConsumerState<TodayCustomersScreen> createState() =>
      _TodayCustomersScreenState();
}

class _TodayCustomersScreenState extends ConsumerState<TodayCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.scan),
            tooltip: 'سکانی QR',
            onPressed: () {
              CameraBarcodeScanner.show(context, (barcode) {
                // If the barcode is in format CUST-123
                if (barcode.startsWith('CUST-')) {
                  final customerId = barcode.split('-')[1];
                  context.push('/customer/$customerId');
                } else {
                  setState(() {
                    _searchQuery = barcode;
                    _searchController.text = barcode;
                  });
                }
              });
            },
          ),
          IconButton(icon: const Icon(AppIcons.filter), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppTextField(
              hintText: 'گەڕان بۆ کڕیار...',
              prefixIcon: AppIcons.search,
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          // Mandatory visit order warning notice
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xs,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'ئاگاداری: ڕێزبەندی سەردانەکان ناچارکەرە. تکایە بەپێی ئەم ڕێزبەندییەی خوارەوە سەردانی کڕیاران بکە.',
                      style: TextStyle(
                        fontFamily: 'Rudaw',
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => LayoutBuilder(
                builder: (context, constraints) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customerListProvider),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ErrorState(
                          title: 'هەڵەیەک ڕوویدا',
                          message: Formatters.cleanError(error),
                          retryText: 'دووبارە هەوڵبدەرەوە',
                          onRetry: () => ref.invalidate(customerListProvider),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              data: (customers) {
                // Sort customers by routeId first, then by visitOrder, then by name
                var sorted = List<Customer>.from(customers);
                sorted.sort((a, b) {
                  final aRouteId = a.routeId ?? 999999;
                  final bRouteId = b.routeId ?? 999999;
                  if (aRouteId != bRouteId) {
                    return aRouteId.compareTo(bRouteId);
                  }
                  final aOrder = a.visitOrder ?? 999999;
                  final bOrder = b.visitOrder ?? 999999;
                  if (aOrder != bOrder) {
                    return aOrder.compareTo(bOrder);
                  }
                  return a.name.compareTo(b.name);
                });

                var filtered = sorted
                    .where(
                      (c) => c.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) => RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(customerListProvider),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: const Center(
                            child: Text('هیچ کڕیارێک نەدۆزرایەوە.'),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customerListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      final bool isVisited = false; // Add real logic here later

                      return AppCard(
                        onTap: () {
                          context.push('/customer/${customer.id}');
                        },
                        child: Row(
                          children: [
                            // Mandatory visit order sequence number badge
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${customer.visitOrder ?? index + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'Rudaw',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            CustomerAvatar(
                              imageUrl: customer.imageUrl,
                              size: 40,
                              borderRadius: 20,
                              iconSize: 20,
                              placeholderIcon: AppIcons.customer,
                              backgroundColor: isVisited
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : null,
                              iconColor: isVisited ? AppColors.success : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customer.phone ?? 'بێ ژمارە',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(
                                  label: isVisited ? 'سەردانکراوە' : 'چاوەڕێ',
                                  type: isVisited
                                      ? StatusBadgeType.success
                                      : StatusBadgeType.neutral,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'قەرز: ${Formatters.currency(customer.balance)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: customer.balance > 0
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
