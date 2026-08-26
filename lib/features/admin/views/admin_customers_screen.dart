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

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      0,
                      AppSpacing.screenHorizontal,
                      80,
                    ),
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final bool hasDebt = customer.balance > 0;

                      return AppCard(
                        onTap: () {
                          context.push('/customer/${customer.id}');
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                AppIcons.customer,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: AppTextStyles.bodyBold),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${customer.address ?? 'بێ ناونیشان'} • ${customer.phone ?? ''}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (hasDebt) ...[
                                  Text('قەرزدار', style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
                                  Text(
                                    '${customer.balance.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع',
                                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ] else ...[
                                  Text('پاکە', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                                  Text('0 د.ع', style: AppTextStyles.bodyBold.copyWith(color: AppColors.success)),
                                ],
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAddCustomerDialog(context, customer);
                                } else if (value == 'delete') {
                                  _showDeleteCustomerDialog(context, customer);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20),
                                      SizedBox(width: 8),
                                      Text('دەستکاریکردن'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                      SizedBox(width: 8),
                                      Text('سڕینەوە', style: TextStyle(color: AppColors.danger)),
                                    ],
                                  ),
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

