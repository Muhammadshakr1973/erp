import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/app_dialog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/suppliers_provider.dart';
import 'supplier_form_dialog.dart';

class AdminPurchasesScreen extends ConsumerStatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  ConsumerState<AdminPurchasesScreen> createState() => _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends ConsumerState<AdminPurchasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => const SupplierFormDialog(),
    ).then((success) {
      if (success == true) {
        ref.invalidate(suppliersListProvider);
      }
    });
  }

  void _showEditSupplierDialog(BuildContext context, SupplierModel supplier) {
    showDialog<bool>(
      context: context,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    ).then((success) {
      if (success == true) {
        ref.invalidate(suppliersListProvider);
      }
    });
  }

  void _deleteSupplier(BuildContext context, SupplierModel supplier) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'سڕینەوەی کۆمپانیا',
      message: 'دڵنیایت لە سڕینەوەی کۆمپانیای "${supplier.name}"؟',
      confirmText: 'سڕینەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(supplierActionsProvider).deleteSupplier(supplier.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کۆمپانیا بە سەرکەوتوویی سڕایەوە')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('کێشە لە سڕینەوە: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازاڕ و کۆمپانیا', style: AppTextStyles.h2),
        actions: [
          if (_tabController.index == 2)
            IconButton(
              icon: const Icon(AppIcons.add),
              onPressed: () => _showAddSupplierDialog(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'پێویست بۆ کڕین'),
            Tab(text: 'پسوڵەکانی کڕین'),
            Tab(text: 'کۆمپانیاکان'),
          ],
          labelStyle: AppTextStyles.bodyBold,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequirementsTab(context),
          _buildPurchaseOrdersTab(context),
          _buildSuppliersTab(context),
        ],
      ),
    );
  }

  Widget _buildRequirementsTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.danger),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('کاڵای پێویست ژمارە ${index + 1}', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    const Text('کۆگای سەرەکی • داواکراو: 50', style: AppTextStyles.caption),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_checkout, color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchaseOrdersTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final isReceived = index % 2 == 0;
        return AppCard(
          onTap: () {},
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(AppIcons.order),
            ),
            title: Text('پسوڵەی کڕین #500$index', style: AppTextStyles.bodyBold),
            subtitle: const Text('کۆمپانیای جێگر • 10 کاڵا', style: AppTextStyles.caption),
            trailing: StatusBadge(
              label: isReceived ? 'گەیشتووە' : 'چاوەڕوانە',
              type: isReceived ? StatusBadgeType.success : StatusBadgeType.warning,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return suppliersAsync.when(
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'هیچ کۆمپانیایەک نییە',
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => _showAddSupplierDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('زیادکردنی کۆمپانیا'),
                ),
              ],
            ),
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        int crossAxisCount = 1;
        if (screenWidth >= 1024) {
          crossAxisCount = 3;
        } else if (screenWidth >= 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: suppliers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, index) => _buildSupplierCard(context, suppliers[index]),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text(
          'شکست لە هێنانی زانیارییەکان: $error',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
    );
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Widget _buildSupplierCard(BuildContext context, SupplierModel supplier) {
    final theme = Theme.of(context);
    final bool hasDebt = supplier.debt > 0;

    return AppCard(
      onTap: () => _showEditSupplierDialog(context, supplier),
      onLongPress: () => _deleteSupplier(context, supplier),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.storefront, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    supplier.name,
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'کەسی پەیوەندی: ${supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty ? supplier.contactPerson : '-'}',
                    style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${supplier.phone ?? 'مۆبایل نییە'} • ${supplier.address ?? 'ناونیشان نییە'}',
                    style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
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
                Text(
                  'کۆد: #${supplier.id}',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasDebt
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrency(supplier.debt),
                        style: AppTextStyles.bodyBold.copyWith(
                          color: hasDebt ? AppColors.danger : AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasDebt ? AppColors.danger : AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasDebt ? 'قەرزدار' : 'پاکە',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Rudaw',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
