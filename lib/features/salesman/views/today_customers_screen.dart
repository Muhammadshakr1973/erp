import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/customer_avatar.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/models/customer.dart';
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
    final theme = Theme.of(context);
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
                // Customer 0 (Temporary Customer) is ALWAYS at the absolute top,
                // and other customers are sorted alphabetically by name
                var sorted = List<Customer>.from(customers);
                sorted.sort((a, b) {
                  if (a.id == 0) return -1;
                  if (b.id == 0) return 1;
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

                      return AppCard(
                        onTap: () {
                          context.push('/customer/${customer.id}');
                        },
                        child: Row(
                          children: [
                            CustomerAvatar(
                              imageUrl: customer.imageUrl,
                              size: 40,
                              borderRadius: 20,
                              iconSize: 20,
                              placeholderIcon: AppIcons.customer,
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
                                  if (customer.route?.name != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      customer.route!.name,
                                      style: AppTextStyles.caption.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  customer.balance > 0
                                      ? 'قەرز: ${Formatters.currency(customer.balance)}'
                                      : 'بێ قەرز',
                                  style: AppTextStyles.caption.copyWith(
                                    color: customer.balance > 0
                                        ? AppColors.danger
                                        : AppColors.success,
                                    fontWeight: FontWeight.bold,
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
