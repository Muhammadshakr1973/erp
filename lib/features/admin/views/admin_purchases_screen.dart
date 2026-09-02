import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/app_dialog.dart';
import '../../../core/components/permission_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../products/models/supplier_model.dart';
import '../../products/providers/suppliers_provider.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_provider.dart';
import '../../products/views/supplier_reconciliation_dialog.dart';
import 'supplier_form_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class AdminPurchasesScreen extends ConsumerStatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  ConsumerState<AdminPurchasesScreen> createState() =>
      _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends ConsumerState<AdminPurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedRequirementIds = {};
  bool _isConverting = false;

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

    if (confirmed == true && mounted) {
      try {
        await ref.read(supplierActionsProvider).deleteSupplier(supplier.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کۆمپانیا بە سەرکەوتوویی سڕایەوە')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('کێشە لە سڕینەوە: $e')));
        }
      }
    }
  }

  void _convertSelectedToPO() async {
    if (_selectedRequirementIds.isEmpty) return;

    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'دروستکردنی پسوڵەی کڕین',
            style: AppTextStyles.bodyBold,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ئایا دڵنیایت لە گۆڕینی ${_selectedRequirementIds.length} داواکاری بۆ پسوڵەی کڕین؟',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'تێبینییەکان (ئارەزوومەندانە)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تۆمارکردن'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isConverting = true;
      });
      try {
        await ref
            .read(purchaseActionsProvider)
            .convertRequirementsToPO(
              requirementIds: _selectedRequirementIds.toList(),
              notes: notesController.text,
            );
        setState(() {
          _selectedRequirementIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'داواکارییەکان بە سەرکەوتوویی گۆڕدران بۆ پسوڵەی کڕین',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isConverting = false;
          });
        }
      }
    }
  }

  void _confirmPO(PurchaseOrderModel order) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'پەسەندکردنی پسوڵەی کڕین',
      message:
          'ئایا دڵنیایت لە پەسەندکردنی پسوڵەی کڕینی #${order.orderNumber}؟',
      confirmText: 'پەسەندکردن',
      cancelText: 'پەشیمانبوونەوە',
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پسوڵەی کڕین پەسەند دەکرێت...')),
      );
      try {
        await ref.read(purchaseActionsProvider).confirmPurchaseOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پسوڵەی کڕین بەسەرکەوتوویی پەسەندکرا'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  void _receivePO(PurchaseOrderModel order) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'وەرگرتنی کاڵاکان لە کۆگا',
      message:
          'ئایا دڵنیایت لە وەرگرتنی کاڵاکانی پسوڵەی کڕینی #${order.orderNumber}؟ ئەم کردارە ستۆکی کۆگا زیاد دەکات و قەرزەکە دەخاتە سەر کۆمپانیا.',
      confirmText: 'وەرگرتن',
      cancelText: 'پەشیمانبوونەوە',
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('داواکارییەکە جێبەجێ دەکرێت...')),
      );
      try {
        await ref.read(purchaseActionsProvider).receivePurchaseOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'پسوڵەی کڕین بەسەرکەوتوویی وەرگیرا و ستۆک نوێکرایەوە',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  void _cancelPO(PurchaseOrderModel order) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'هەڵوەشاندنەوەی پسوڵەی کڕین',
      message:
          'ئایا دڵنیایت لە هەڵوەشاندنەوەی پسوڵەی کڕینی #${order.orderNumber}؟ بەم کارە داواکارییەکان دەگەڕێنەوە لیستی داواکاری کراوە.',
      confirmText: 'هەڵوەشاندنەوە',
      cancelText: 'پەشیمانبوونەوە',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پسوڵەی کڕین هەڵدەوەشێنرێتەوە...')),
      );
      try {
        await ref.read(purchaseActionsProvider).cancelPurchaseOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پسوڵەی کڕین بەسەرکەوتوویی هەڵوەشێنرایەوە'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'suppliers.manage',
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
    final reqsAsync = ref.watch(purchaseRequirementsProvider);
    final groupedAsync = ref.watch(purchaseRequirementsGroupProvider);
    final theme = Theme.of(context);

    return reqsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('کێشەیەک لە بارکردنی داواکارییەکان دروستبوو'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(purchaseRequirementsProvider);
                  ref.invalidate(purchaseRequirementsGroupProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
      ),
      data: (requirements) {
        if (requirements.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(purchaseRequirementsProvider);
              ref.invalidate(purchaseRequirementsGroupProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'هیچ داواکاری کڕینێکی کراوە بەردەست نییە',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'کاتێک ستۆک تەواو دەبێت لە کاتی پسوڵەی فرۆشتن، داواکاری لێرە دەردەکەوێت',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(purchaseRequirementsProvider);
            ref.invalidate(purchaseRequirementsGroupProvider);
          },
          child: Column(
            children: [
              groupedAsync.maybeWhen(
                data: (groups) {
                  if (groups.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.xs,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text('گرووپی کۆمپانیاکان: ', style: AppTextStyles.caption),
                          const SizedBox(width: AppSpacing.xs),
                          ...groups.map((group) {
                            final String name = group['supplier_name'] ?? 'بێ دابینکەر';
                            final int count = group['items_count'] ?? 0;
                            final List reqList = group['requirements'] ?? [];

                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: ActionChip(
                                label: Text('$name ($count)', style: AppTextStyles.caption),
                                onPressed: () {
                                  setState(() {
                                    for (var item in reqList) {
                                      final id = item['id'];
                                      if (id is int) {
                                        _selectedRequirementIds.add(id);
                                      }
                                    }
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              if (_selectedRequirementIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'هەڵبژێردراو: ${_selectedRequirementIds.length} دانە',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      _isConverting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ElevatedButton.icon(
                              onPressed: _convertSelectedToPO,
                              icon: const Icon(Icons.shopping_cart_checkout),
                              label: const Text('دروستکردنی پسوڵەی کڕین (PO)'),
                            ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: requirements.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final req = requirements[index];
                    final isSelected = _selectedRequirementIds.contains(req.id);

                    return AppCard(
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedRequirementIds.add(req.id);
                                } else {
                                  _selectedRequirementIds.remove(req.id);
                                }
                              });
                            },
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: req.isUrgent
                                  ? AppColors.danger.withValues(alpha: 0.1)
                                  : theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              req.isUrgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory_2_outlined,
                              color: req.isUrgent
                                  ? AppColors.danger
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        req.productName,
                                        style: AppTextStyles.bodyBold,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (req.isUrgent)
                                      const StatusBadge(
                                        label: 'بەپەلە',
                                        type: StatusBadgeType.danger,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'کۆمپانیا: ${req.supplierName ?? 'بێ کۆمپانیا'} • کۆگا: ${req.warehouseName}',
                                  style: AppTextStyles.caption,
                                ),
                                if (req.salesOrderId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'لەلایەن پسوڵەی فرۆشتنی: #${req.salesOrderId}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(
                                label: 'بڕی پێویست: ${req.requiredQuantity}',
                                type: StatusBadgeType.warning,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'مەوجود: ${req.currentStock}',
                                style: AppTextStyles.caption,
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
          ),
        );
      },
    );
  }

  Widget _buildPurchaseOrdersTab(BuildContext context) {
    final posAsync = ref.watch(purchaseOrdersProvider);
    final theme = Theme.of(context);

    return posAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('کێشەیەک لە بارکردنی پسوڵەکان دروستبوو'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(purchaseOrdersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('دووبارە هەوڵبدەرەوە'),
              ),
            ],
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'هیچ پسوڵەیەکی کڕین تۆمار نەکراوە',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: orders.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.status.toUpperCase();
              final isDraft = status == 'DRAFT';
              final isConfirmed = status == 'CONFIRMED';
              final isReceived = status == 'RECEIVED';
              final isCancelled = status == 'CANCELLED';

              String badgeLabel = 'ڕەشنووس';
              StatusBadgeType badgeType = StatusBadgeType.warning;
              if (isConfirmed) {
                badgeLabel = 'پەسەندکراوە';
                badgeType = StatusBadgeType.info;
              } else if (isReceived) {
                badgeLabel = 'وەرگیراوە';
                badgeType = StatusBadgeType.success;
              } else if (isCancelled) {
                badgeLabel = 'هەڵوەشاوە';
                badgeType = StatusBadgeType.danger;
              }

              return AppCard(
                onTap: isConfirmed ? () => _receivePO(order) : null,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isReceived
                        ? AppColors.success.withValues(alpha: 0.1)
                        : (isConfirmed
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest),
                    child: Icon(
                      AppIcons.order,
                      color: isReceived
                          ? AppColors.success
                          : theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'پسوڵەی کڕین #${order.orderNumber}',
                    style: AppTextStyles.bodyBold,
                  ),
                  subtitle: Text(
                    '${order.supplierName} • ${order.itemsCount} کاڵا • ${_formatCurrency(order.totalAmount)}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: badgeLabel,
                        type: badgeType,
                      ),
                      if (isDraft)
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                          tooltip: 'پەسەندکردن',
                          onPressed: () => _confirmPO(order),
                        ),
                      if (isConfirmed)
                        IconButton(
                          icon: const Icon(Icons.download_done, color: AppColors.success),
                          tooltip: 'وەرگرتن',
                          onPressed: () => _receivePO(order),
                        ),
                      if (isDraft || isConfirmed)
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                          tooltip: 'هەڵوەشاندنەوە',
                          onPressed: () => _cancelPO(order),
                        ),
                    ],
                  ),
                ),
              );
            },
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
            mainAxisExtent: 130,
          ),
          itemBuilder: (context, index) =>
              _buildSupplierCard(context, suppliers[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'شکست لە هێنانی زانیارییەکان: $error',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
    );
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Widget _buildSupplierCard(BuildContext context, SupplierModel supplier) {
    final theme = Theme.of(context);
    final bool hasDebt = supplier.debt > 0;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final canReconcile = user?.hasPermission('users.manage') ?? false;

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
              child: Icon(
                Icons.storefront,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (canReconcile)
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet_outlined,
                              size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  SupplierReconciliationDialog(
                                      supplier: supplier),
                            );
                          },
                          tooltip: 'لێکترازانی دارایی',
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'کەسی پەیوەندی: ${supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty ? supplier.contactPerson : '-'}',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${supplier.phone ?? 'مۆبایل نییە'} • ${supplier.address ?? 'ناونیشان نییە'}',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
