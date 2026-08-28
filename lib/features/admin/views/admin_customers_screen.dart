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
import '../../shared/models/route_model.dart';
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
  int? _selectedRouteId;
  bool _onlyDebtors = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1; // Reset to page 1 on search
        });
      }
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
        ref.invalidate(filteredCustomerListProvider);
        ref.invalidate(customerListProvider);
      }
    });
  }

  void _showDeleteCustomerDialog(BuildContext context, Customer customer) {
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
                ref.invalidate(filteredCustomerListProvider);
                ref.invalidate(customerListProvider);
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
    final routesAsync = ref.watch(routeListProvider);

    // Build api query parameters
    final Map<String, dynamic> apiFilters = {
      'page': _currentPage,
      if (_selectedRouteId != null) 'route_id': _selectedRouteId,
      if (_onlyDebtors) 'has_debt': 'true',
      if (_searchQuery.isNotEmpty) 'search': _searchQuery,
    };

    final customersAsync = ref.watch(filteredCustomerListProvider(apiFilters));

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
              ref.invalidate(filteredCustomerListProvider);
              ref.invalidate(customerListProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: AppTextField(
              controller: _searchController,
              hintText: 'گەڕان بۆ کڕیار، تەلەفۆن...',
              prefixIcon: AppIcons.search,
            ),
          ),

          // Filters Row (Routes & Debt Filter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            child: routesAsync.when(
              data: (routes) => _buildFiltersBar(context, routes),
              loading: () => const SizedBox(height: 48, child: Center(child: LinearProgressIndicator())),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('هەڵە لە بارکردنی ڕاوتەکان: $err', style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Customer Grid List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(filteredCustomerListProvider);
                ref.invalidate(customerListProvider);
              },
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: AppSpacing.md),
                        Text('کێشەیەک ڕوویدا لە بارکردنی داتاکان:', style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 4),
                        Text('$error', style: AppTextStyles.caption.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          text: 'دووبارە هەوڵبدەرەوە',
                          onPressed: () {
                            ref.invalidate(filteredCustomerListProvider);
                            ref.invalidate(customerListProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                data: (customers) {
                  if (customers.isEmpty) {
                    return _buildEmptyState(theme);
                  }

                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (screenWidth >= 1024) {
                    crossAxisCount = 3;
                  } else if (screenWidth >= 600) {
                    crossAxisCount = 2;
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                            vertical: AppSpacing.xs,
                          ),
                          itemCount: customers.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            mainAxisExtent: 145,
                          ),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return _buildCustomerCard(context, customer);
                          },
                        ),
                      ),
                      // Pagination Controls
                      _buildPaginationRow(context, customers.length),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context, List<RouteModel> routes) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // Debt filter toggle
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: FilterChip(
              selected: _onlyDebtors,
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('قەرزارەکان '),
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _onlyDebtors = selected;
                  _currentPage = 1;
                });
              },
              selectedColor: AppColors.danger.withValues(alpha: 0.15),
              checkmarkColor: AppColors.danger,
              labelStyle: AppTextStyles.caption.copyWith(
                color: _onlyDebtors ? AppColors.danger : theme.colorScheme.onSurface,
                fontWeight: _onlyDebtors ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: VerticalDivider(width: 1, indent: 8, endIndent: 8),
          ),

          // All routes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: FilterChip(
              selected: _selectedRouteId == null,
              label: const Text('هەموو گەڕەکەکان'),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRouteId = null;
                    _currentPage = 1;
                  });
                }
              },
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.primary,
              labelStyle: AppTextStyles.caption.copyWith(
                color: _selectedRouteId == null ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: _selectedRouteId == null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // Other routes
          ...routes.map((route) {
            final isSelected = _selectedRouteId == route.id;
            return Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: FilterChip(
                selected: isSelected,
                label: Text(route.name),
                onSelected: (selected) {
                  setState(() {
                    _selectedRouteId = selected ? route.id : null;
                    _currentPage = 1;
                  });
                },
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.primary,
                labelStyle: AppTextStyles.caption.copyWith(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    final theme = Theme.of(context);
    final bool hasDebt = customer.balance > 0;

    String priceTierLabel = 'تاک (N1)';
    Color tierColor = Colors.teal;
    if (customer.priceType == 'N2') {
      priceTierLabel = 'کۆ (N2)';
      tierColor = Colors.blue;
    } else if (customer.priceType == 'N3') {
      priceTierLabel = 'تایبەت (N3)';
      tierColor = Colors.purple;
    }

    String formatCurrency(num amount) {
      return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
    }

    return AppCard(
      onTap: () => _showAddCustomerDialog(context, customer),
      onLongPress: () => _showDeleteCustomerDialog(context, customer),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Profile image or initials
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                image: customer.imageUrl != null && customer.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(customer.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: customer.imageUrl == null || customer.imageUrl!.isEmpty
                  ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),

            // Middle section: details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!customer.isActive) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ناچالاک',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontFamily: 'Rudaw'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.phone ?? 'مۆبایل نییە',
                    style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Route badge
                      Icon(Icons.alt_route, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customer.route?.name ?? 'گەڕەک دیارینەکراوە',
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Left section: Price type & balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Price tier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priceTierLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: tierColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Balance badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasDebt
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasDebt ? formatCurrency(customer.balance) : 'بێ قەرز',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: hasDebt ? AppColors.danger : AppColors.success,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationRow(BuildContext context, int count) {
    final theme = Theme.of(context);
    final hasNext = count >= 20; // 20 is Laravel's default pagination size
    final hasPrev = _currentPage > 1;

    if (!hasNext && !hasPrev) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Next page button (since list is RTL, next is left physically, but let's label them clearly)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            tooltip: 'لاپەڕەی پێشوو',
            onPressed: hasPrev
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
          ),

          // Current page indicator
          Text(
            'لاپەڕە $_currentPage',
            style: AppTextStyles.bodyBold.copyWith(color: theme.colorScheme.primary),
          ),

          // Next page button
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            tooltip: 'لاپەڕەی داهاتوو',
            onPressed: hasNext
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'هیچ کڕیارێک نییە',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'هیچ کڕیارێک بەو مەرجانە نەدۆزرایەوە کە دیاریت کردوون.',
                style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 180,
                child: AppButton(
                  text: 'کڕیاری نوێ زیادبکە',
                  onPressed: () => _showAddCustomerDialog(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
