import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/models/customer.dart';
import '../../shared/providers/customer_provider.dart';
import '../../shared/providers/route_provider.dart';
import '../../shared/views/customer_form_dialog.dart';

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  ConsumerState<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context, [Customer? customer]) {
    showDialog<bool>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    ).then((success) {
      if (success == true) {
        ref.invalidate(customerListProvider);
      }
    });
  }

  void _showDeleteCustomerDialog(BuildContext context, Customer customer) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی کڕیار', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دڵنیایت لە سڕینەوەی کڕیاری "${customer.name}"؟'),
            if (customer.balance > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ئاگاداربە: ئەم کڕیارە بڕی ${customer.balance.toInt()} د.ع قەرزی لەسەرە!',
                        style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(customerActionsProvider).deleteCustomer(customer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('کڕیار بە سەرکەوتوویی سڕایەوە'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە لە سڕینەوە: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);
    final routesAsync = ref.watch(routeListProvider);
    final Map<int, String> routeNames = {};
    routesAsync.whenData((routes) {
      for (var r in routes) {
        routeNames[r.id] = r.name;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('لیستی کڕیارەکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'زیادکردنی کڕیار',
            onPressed: () => _showAddCustomerDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () {
              ref.invalidate(customerListProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('کڕیاری نوێ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppTextField(
              controller: _searchController,
              hintText: 'گەڕان بۆ کڕیار، ناونیشان، تەلەفۆن...',
              prefixIcon: AppIcons.search,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(customerListProvider),
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('هەڵەیەک ڕوویدا: $error', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'دووبارە هەوڵبدەرەوە',
                        onPressed: () => ref.invalidate(customerListProvider),
                      ),
                    ],
                  ),
                ),
                data: (customers) {
                  List<Customer> filteredCustomers = customers;
                  if (_searchQuery.isNotEmpty) {
                    filteredCustomers = customers.where((c) {
                      final nameMatch = c.name.toLowerCase().contains(_searchQuery);
                      final phoneMatch = c.phone?.toLowerCase().contains(_searchQuery) ?? false;
                      final phone2Match = c.phone2?.toLowerCase().contains(_searchQuery) ?? false;
                      final addressMatch = c.address?.toLowerCase().contains(_searchQuery) ?? false;
                      return nameMatch || phoneMatch || phone2Match || addressMatch;
                    }).toList();
                  }

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _searchQuery.isEmpty ? 'هیچ کڕیارێک نییە' : 'هیچ کڕیارێک بەم ناوە نەدۆزرایەوە',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_searchQuery.isEmpty)
                            SizedBox(
                              width: 180,
                              child: AppButton(
                                text: 'کڕیاری نوێ زیادبکە',
                                onPressed: () => _showAddCustomerDialog(context),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (screenWidth >= 1200) {
                    crossAxisCount = 3;
                  } else if (screenWidth >= 600) {
                    crossAxisCount = 2;
                  }

                  String formatCurrency(num amount) {
                    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      0,
                      AppSpacing.screenHorizontal,
                      80,
                    ),
                    itemCount: filteredCustomers.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.sm,
                      mainAxisExtent: 96,
                    ),
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final bool hasDebt = customer.balance > 0;

                      return AppCard(
                        onTap: () => _showAddCustomerDialog(context, customer),
                        onLongPress: () => _showDeleteCustomerDialog(context, customer),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.person, color: Colors.grey),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    customer.name, 
                                    style: AppTextStyles.bodyBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${customer.phone ?? 'مۆبایل نییە'} • ${customer.address ?? 'ناونیشان نییە'}${customer.routeId != null && routeNames.containsKey(customer.routeId) ? ' • ${routeNames[customer.routeId]}' : ''}',
                                    style: AppTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('قەرز', style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(
                                  hasDebt ? formatCurrency(customer.balance) : '0 د.ع',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: hasDebt ? AppColors.danger : AppColors.success,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

