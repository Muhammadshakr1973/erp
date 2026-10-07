import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_text_field.dart';
import '../../../../core/components/customer_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../salesman/providers/salesman_dashboard_provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerSelectionDialog extends ConsumerStatefulWidget {
  const CustomerSelectionDialog({super.key});

  static Future<Customer?> show(BuildContext context) {
    return showDialog<Customer>(
      context: context,
      builder: (context) => const CustomerSelectionDialog(),
    );
  }

  @override
  ConsumerState<CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState
    extends ConsumerState<CustomerSelectionDialog> {
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
    final dashboardAsync = ref.watch(salesmanDashboardProvider);

    final todayRouteId = dashboardAsync.asData?.value.todayRouteId;
    final todayRouteName = dashboardAsync.asData?.value.routeName;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        width: double.maxFinite,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('دیاریکردنی کڕیار', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _searchController,
              hintText: 'گەڕان بەپێی ناوی کڕیار یان تەلەفۆن...',
              prefixIcon: AppIcons.search,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('هەڵە لە بارکردنی کڕیاران: $err')),
                data: (customers) {
                  final filtered = customers.where((c) {
                    final matchesName = c.name.toLowerCase().contains(
                      _searchQuery,
                    );
                    final matchesPhone = (c.phone ?? '').toLowerCase().contains(
                      _searchQuery,
                    );
                    return matchesName || matchesPhone;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('هیچ کڕیارێک نەدۆزرایەوە'));
                  }

                  // Separate into today's route customers, other route customers & temporary customer
                  final List<Customer> todayCustomers = [];
                  final List<Customer> otherCustomers = [];
                  Customer? tempCustomer;

                  for (final c in filtered) {
                    if (c.id == 0) {
                      tempCustomer = c;
                    } else if (todayRouteId != null && c.routeId == todayRouteId) {
                      todayCustomers.add(c);
                    } else {
                      otherCustomers.add(c);
                    }
                  }

                  // Build list items
                  final List<Widget> listItems = [];

                  // Section 0: Highlighted Temporary Customer Card
                  if (tempCustomer != null) {
                    listItems.add(
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                          ),
                          title: Text(
                            tempCustomer.name,
                            style: AppTextStyles.bodyBold.copyWith(color: Colors.orange.shade800),
                          ),
                          subtitle: const Text('دروستکردنی پسوڵە بەبێ دیاریکردنی پێشوەختەی کڕیار'),
                          onTap: () {
                            Navigator.of(context).pop(tempCustomer);
                          },
                        ),
                      ),
                    );
                  }

                  // Section 1: Today's Route Customers (if available)
                  if (todayCustomers.isNotEmpty) {
                    listItems.add(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs + 2,
                        ),
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alt_route,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'کڕیارەکانی ڕاوتی گەڕەکی ئەمڕۆ${(todayRouteName != null && todayRouteName.isNotEmpty) ? " ($todayRouteName)" : ""}',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${todayCustomers.length} کڕیار',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    for (final customer in todayCustomers) {
                      listItems.add(_buildCustomerTile(context, customer));
                    }
                  }

                  // Divider between Today's Route & Other Routes
                  if (todayCustomers.isNotEmpty && otherCustomers.isNotEmpty) {
                    listItems.add(
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(
                          thickness: 1.5,
                          height: 24,
                        ),
                      ),
                    );
                  }

                  // Section 2: Other Route Customers
                  if (otherCustomers.isNotEmpty) {
                    if (todayCustomers.isNotEmpty) {
                      listItems.add(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs + 2,
                          ),
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'کڕیارەکانی ڕاوتەکانی تر',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${otherCustomers.length} کڕیار',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    for (final customer in otherCustomers) {
                      listItems.add(_buildCustomerTile(context, customer));
                    }
                  }

                  return ListView.builder(
                    itemCount: listItems.length,
                    itemBuilder: (context, index) => listItems[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTile(BuildContext context, Customer customer) {
    return ListTile(
      leading: CustomerAvatar(
        imageUrl: customer.imageUrl,
        size: 40,
        borderRadius: 20,
        iconSize: 20,
      ),
      title: Text(
        customer.name,
        style: AppTextStyles.bodyBold,
      ),
      subtitle: Text(
        '${customer.phone ?? 'بێ ژمارە'}${customer.route?.name != null ? " • ${customer.route!.name}" : ""}',
      ),
      trailing: customer.balance > 0
          ? Text(
              Formatters.currency(customer.balance),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      onTap: () {
        Navigator.of(context).pop(customer);
      },
    );
  }
}
