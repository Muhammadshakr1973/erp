import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/providers/warehouse_provider.dart';
import 'providers/user_provider.dart';

class AdminWarehousesScreen extends ConsumerStatefulWidget {
  const AdminWarehousesScreen({super.key});

  @override
  ConsumerState<AdminWarehousesScreen> createState() =>
      _AdminWarehousesScreenState();
}

class _AdminWarehousesScreenState extends ConsumerState<AdminWarehousesScreen> {
  String _selectedFilter = 'ALL'; // ALL, PHYSICAL_DIRECT, PHYSICAL_RESERVE, VAN
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showWarehouseFormDialog([WarehouseModel? warehouse]) {
    final nameController = TextEditingController(text: warehouse?.name ?? '');
    final addressController =
        TextEditingController(text: warehouse?.address ?? '');
    bool isMain = warehouse?.isMain ?? false;
    bool isActive = warehouse?.isActive ?? true;

    // Normalize type
    String type = warehouse?.type ?? 'PHYSICAL_DIRECT';
    if (type == 'PHYSICAL') {
      type = 'PHYSICAL_DIRECT';
    }

    int? selectedCashVanUserId = warehouse?.cashVanUserId;
    final List<int> selectedKeeperIds = List<int>.from(warehouse?.keeperIds ?? []);
    final List<int> selectedSalesmanIds = List<int>.from(warehouse?.salesmanIds ?? []);

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final keepersAsync = ref.watch(warehouseKeepersListProvider);
            final cashVanSalesmenAsync = ref.watch(cashVanSalesmenListProvider);
            final presellSalesmenAsync = ref.watch(presellSalesmenListProvider);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final isVan = type == 'VAN';
                final isReserve = type == 'PHYSICAL_RESERVE';
                final isDirect = type == 'PHYSICAL_DIRECT';

                return AlertDialog(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          warehouse == null ? 'زیادکردنی کۆگای نوێ' : 'دەستکاریکردنی کۆگا',
                          style: AppTextStyles.bodyBold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        tooltip: 'داخستن',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: nameController,
                            labelText: 'ناوی کۆگا *',
                            hintText: 'بۆ نموونە: کۆگای سەرەکی، یەدەگی باکوور، یان کاشڤان - هەژار',
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Warehouse Type Selection
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'جۆری کۆگا *',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'PHYSICAL_DIRECT',
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_outlined,
                                        size: 20, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'کۆگای فیزیکی - فرۆشتنی ڕاستەوخۆ',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'PHYSICAL_RESERVE',
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 20, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'کۆگای فیزیکی - یەدەگ (تەنها بۆ پڕکردنەوە)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'VAN',
                                child: Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined,
                                        size: 20, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'ئۆتۆمبێلی کاشڤان (گەڕۆک)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  type = val;
                                  if (type == 'VAN' || type == 'PHYSICAL_RESERVE') {
                                    isMain = false;
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Conditional fields for VAN
                          if (isVan) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'ئەم کۆگایە تایبەتە بە ئۆتۆمبێلی مەندوبێکی کاشڤان. ناونیشان و ژمارەی مۆبایل پێویست نییە چونکە کاشڤانەکە دیاریدەکرێت.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            cashVanSalesmenAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text(
                                'کێشە لە بارکردنی کاشڤانەکان: ${Formatters.cleanError(e)}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                              ),
                              data: (cashVans) {
                                return DropdownButtonFormField<int?>(
                                  initialValue: selectedCashVanUserId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'دیاریکردنی کاشڤان (مەندوبی گەڕۆک) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_pin_outlined, color: Colors.orange),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        'دیاری نەکراوە (هەڵبژێرە...)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ...cashVans.map((cv) {
                                      return DropdownMenuItem<int?>(
                                        value: cv.id,
                                        child: Text(
                                          '${cv.name} (${cv.phone})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedCashVanUserId = val;
                                      if (val != null && nameController.text.trim().isEmpty) {
                                        final matched = cashVans.firstWhere((c) => c.id == val);
                                        nameController.text = 'کۆگای کاشڤان - ${matched.name}';
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ],

                          // Conditional fields for Physical (DIRECT & RESERVE)
                          if (!isVan) ...[
                            AppTextField(
                              controller: addressController,
                              labelText: 'ناونیشان / شوێن',
                              hintText: 'بۆ نموونە: هەولێر - شەقامی ٦٠ مەتری، کۆگاکانی باشوور',
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Main Warehouse Switch (Only for DIRECT sales physical warehouse)
                            if (isDirect) ...[
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('کۆگای بنەڕەتی و سەرەکی (Main)'),
                                subtitle: const Text(
                                  'پسوڵەکان بە شێوەی خۆکار لەم کۆگایەوە دروست دەکرێن ئەگەر دیاری نەکرابێت.',
                                  style: AppTextStyles.caption,
                                ),
                                value: isMain,
                                onChanged: (val) {
                                  setDialogState(() {
                                    isMain = val;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ] else if (isReserve) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined,
                                        size: 18, color: Colors.purple),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'کۆگای یەدەگ تەنها بۆ پڕکردنەوە و گواستنەوەی کاڵایە بۆ کۆگاکانی تر. هیچ فرۆشێکی لێ ئەنجام نادرێت و نابێتە کۆگای سەرەکی.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            // Multi-select for Warehouse Keepers (Both Direct & Reserve)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.badge_outlined, size: 18),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'کارمەندانی کۆگا (Warehouse Keepers)',
                                          style: AppTextStyles.bodyBold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'دەتوانیت یەک یان چەند کارمەندێک دیاری بکەیت. هەر کارمەندێک دەتوانێت لە چەندین کۆگادا کاربکات.',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(height: 8),
                                  keepersAsync.when(
                                    loading: () => const LinearProgressIndicator(),
                                    error: (e, _) => Text(
                                      'کێشە لە بارکردنی کارمەندان: ${Formatters.cleanError(e)}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                    ),
                                    data: (keepers) {
                                      if (keepers.isEmpty) {
                                        return const Text(
                                          'هیچ بەکارهێنەرێک بە ڕۆڵی کارمەندی کۆگا (Warehouse) تۆمار نەکراوە.',
                                          style: AppTextStyles.caption,
                                        );
                                      }
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: keepers.map((k) {
                                          final isSelected = selectedKeeperIds.contains(k.id);
                                          return FilterChip(
                                            avatar: Icon(
                                              isSelected ? Icons.check_circle : Icons.person_outline,
                                              size: 16,
                                              color: isSelected ? Colors.white : null,
                                            ),
                                            label: Text(k.name),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setDialogState(() {
                                                if (selected) {
                                                  selectedKeeperIds.add(k.id);
                                                } else {
                                                  selectedKeeperIds.remove(k.id);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Multi-select for Salesmen (Only for DIRECT sales physical warehouse)
                            if (isDirect) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.support_agent_outlined, size: 18),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Text(
                                            'مەندوبەکانی فرۆشتن لەم کۆگایەوە (Salesmen)',
                                            style: AppTextStyles.bodyBold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'دیاریکردنی ئەو مەندوبانەی لەم کۆگایەوە دەفرۆشن (ڕاستەوخۆ لە ستۆکی ئەم کۆگایە دەبڕدرێت).',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: 8),
                                    presellSalesmenAsync.when(
                                      loading: () => const LinearProgressIndicator(),
                                      error: (e, _) => Text(
                                        'کێشە لە بارکردنی مەندوبەکان: ${Formatters.cleanError(e)}',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                      ),
                                      data: (salesmen) {
                                        if (salesmen.isEmpty) {
                                          return const Text(
                                            'هیچ مەندوبێکی فرۆشتن (Pre-Sell) تۆمار نەکراوە.',
                                            style: AppTextStyles.caption,
                                          );
                                        }
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: salesmen.map((s) {
                                            final isSelected = selectedSalesmanIds.contains(s.id);
                                            return FilterChip(
                                              avatar: Icon(
                                                isSelected ? Icons.check_circle : Icons.person_outline,
                                                size: 16,
                                                color: isSelected ? Colors.white : null,
                                              ),
                                              label: Text(s.name),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    selectedSalesmanIds.add(s.id);
                                                  } else {
                                                    selectedSalesmanIds.remove(s.id);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ],

                          if (warehouse != null)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('چالاکە'),
                              value: isActive,
                              onChanged: (val) {
                                setDialogState(() {
                                  isActive = val;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    isSubmitting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تکایە ناوی کۆگا بنووسە'),
                                  ),
                                );
                                return;
                              }

                              if (isVan && selectedCashVanUserId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تکایە کاشڤانێک بۆ ئەم ئۆتۆمبێلە دیاری بکە'),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                isSubmitting = true;
                              });

                              try {
                                final actions =
                                    ref.read(warehouseAdminActionsProvider);
                                if (warehouse == null) {
                                  await actions.createWarehouse(
                                    name: name,
                                    address: isVan ? null : addressController.text.trim(),
                                    isMain: isMain,
                                    type: type,
                                    cashVanUserId: isVan ? selectedCashVanUserId : null,
                                    keeperIds: isVan ? null : selectedKeeperIds,
                                    salesmanIds: isDirect ? selectedSalesmanIds : null,
                                  );
                                } else {
                                  await actions.updateWarehouse(
                                    id: warehouse.id,
                                    name: name,
                                    address: isVan ? null : addressController.text.trim(),
                                    isMain: isMain,
                                    isActive: isActive,
                                    type: type,
                                    cashVanUserId: isVan ? selectedCashVanUserId : null,
                                    keeperIds: isVan ? null : selectedKeeperIds,
                                    salesmanIds: isDirect ? selectedSalesmanIds : null,
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        warehouse == null
                                            ? 'کۆگا بە سەرکەوتوویی زیادکرا'
                                            : 'کۆگا بە سەرکەوتوویی نوێکرایەوە',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        Formatters.cleanError(e),
                                      ),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setDialogState(() {
                                    isSubmitting = false;
                                  });
                                }
                              }
                            },
                            child: Text(
                              warehouse == null ? 'زیادکردن' : 'پاشکەوتکردن',
                            ),
                          ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(WarehouseModel warehouse) {
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text('سڕینەوەی کۆگای ${warehouse.name}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: isSubmitting ? null : () => Navigator.pop(context),
                    tooltip: 'داخستن',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: const Text(
                'ئایا دڵنیایت لە سڕینەوەی ئەم کۆگایە؟\nتێبینی: ئەگەر کۆگاکە هەر کاڵایەکی تێدا مابێت سڕینەوەکە ڕەتدەکرێتەوە تاوەکو کاڵاکان بەتاڵ دەکرێن.',
              ),
              actions: [
                isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          try {
                            await ref
                                .read(warehouseAdminActionsProvider)
                                .deleteWarehouse(warehouse.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'کۆگا بە سەرکەوتوویی سڕایەوە',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Formatters.cleanError(e),
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                        child: const Text('بەڵێ، بسڕەوە'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بەڕێوەبردنی کۆگاکان', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'نوێکردنەوە',
            onPressed: () => ref.invalidate(warehouseListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWarehouseFormDialog(),
        tooltip: 'کۆگای نوێ',
        child: const Icon(Icons.add),
      ),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'کێشەیەک ڕوویدا لە بارکردنی کۆگاکان',
            message: Formatters.cleanError(err),
            onRetry: () => ref.invalidate(warehouseListProvider),
          ),
        ),
        data: (warehouses) {
          final directCount = warehouses.where((w) => w.isDirectSale).length;
          final reserveCount = warehouses.where((w) => w.isReserve).length;
          final vanCount = warehouses.where((w) => w.isVan).length;

          final filtered = warehouses.where((w) {
            if (_selectedFilter == 'PHYSICAL_DIRECT' && !w.isDirectSale) {
              return false;
            }
            if (_selectedFilter == 'PHYSICAL_RESERVE' && !w.isReserve) {
              return false;
            }
            if (_selectedFilter == 'VAN' && !w.isVan) {
              return false;
            }

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesName = w.name.toLowerCase().contains(query);
              final matchesAddress =
                  w.address?.toLowerCase().contains(query) ?? false;
              final matchesCashVan =
                  w.cashVanUserName?.toLowerCase().contains(query) ?? false;
              final matchesKeepers =
                  w.keeperNames.any((k) => k.toLowerCase().contains(query));
              final matchesSalesmen =
                  w.salesmanNames.any((s) => s.toLowerCase().contains(query));

              if (!matchesName &&
                  !matchesAddress &&
                  !matchesCashVan &&
                  !matchesKeepers &&
                  !matchesSalesmen) {
                return false;
              }
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(warehouseListProvider);
              await ref.read(warehouseListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // 1. Overview Metric Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    Widget buildStatCard(
                        String title, String value, Color color) {
                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value,
                              style: AppTextStyles.h2.copyWith(color: color),
                            ),
                          ],
                        ),
                      );
                    }

                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: buildStatCard(
                                  'کۆی کۆگاکان',
                                  '${warehouses.length}',
                                  theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: buildStatCard(
                                  'فرۆشتنی ڕاستەوخۆ',
                                  '$directCount',
                                  AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: buildStatCard(
                                  'یەدەگ (پڕکردنەوە)',
                                  '$reserveCount',
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: buildStatCard(
                                  'ئۆتۆمبێلی کاشڤان',
                                  '$vanCount',
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: buildStatCard(
                            'کۆی کۆگاکان',
                            '${warehouses.length}',
                            theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: buildStatCard(
                            'فرۆشتنی ڕاستەوخۆ',
                            '$directCount',
                            AppColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: buildStatCard(
                            'یەدەگ (پڕکردنەوە)',
                            '$reserveCount',
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: buildStatCard(
                            'ئۆتۆمبێلی کاشڤان',
                            '$vanCount',
                            Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Search & Segment Filter Bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 700;
                    final filterButton = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ALL', label: Text('هەموو')),
                          ButtonSegment(
                              value: 'PHYSICAL_DIRECT',
                              label: Text('فرۆشتنی ڕاستەوخۆ')),
                          ButtonSegment(
                              value: 'PHYSICAL_RESERVE', label: Text('یەدەگ')),
                          ButtonSegment(value: 'VAN', label: Text('کاشڤان')),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (set) {
                          setState(() {
                            _selectedFilter = set.first;
                          });
                        },
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _searchController,
                            hintText:
                                'گەڕان بەپێی ناوی کۆگا، ناونیشان، کارمەند، کاشڤان...',
                            prefixIcon: Icons.search,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          filterButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _searchController,
                            hintText:
                                'گەڕان بەپێی ناوی کۆگا، ناونیشان، کارمەند، کاشڤان...',
                            prefixIcon: Icons.search,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        filterButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Warehouses List
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: EmptyState(
                        title: 'هیچ کۆگایەک نەدۆزرایەوە',
                        message: 'بەپێی ئەو فلتەرەی دیاریتکردووە هیچ کۆگایەک نییە.',
                        icon: Icons.warehouse_outlined,
                      ),
                    ),
                  )
                else
                  ...filtered.map((warehouse) {
                    Color badgeColor;
                    IconData typeIcon;
                    String typeLabel;

                    if (warehouse.isVan) {
                      badgeColor = Colors.orange;
                      typeIcon = Icons.local_shipping_outlined;
                      typeLabel = 'کاشڤان (گەڕۆک)';
                    } else if (warehouse.isReserve) {
                      badgeColor = Colors.purple;
                      typeIcon = Icons.inventory_2_outlined;
                      typeLabel = 'کۆگای یەدەگ (تەنها پڕکردنەوە)';
                    } else {
                      badgeColor = AppColors.primary;
                      typeIcon = Icons.storefront_outlined;
                      typeLabel = 'کۆگای فیزیکی (فرۆشتنی ڕاستەوخۆ)';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () => _showWarehouseFormDialog(warehouse),
                        onLongPress: () => _showDeleteDialog(warehouse),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                typeIcon,
                                color: badgeColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    warehouse.name,
                                    style: AppTextStyles.bodyBold,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: badgeColor.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          typeLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                      if (warehouse.isMain)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: const Text(
                                            'سەرەکی (Main)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      if (!warehouse.isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'ناچالاکە',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Location info
                                  if (warehouse.address != null &&
                                      warehouse.address!.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            warehouse.address!,
                                            style: AppTextStyles.caption,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],

                                  // Cash Van Driver info
                                  if (warehouse.isVan) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.person_pin_outlined,
                                            size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            warehouse.cashVanUserName != null
                                                ? 'کاشڤان: ${warehouse.cashVanUserName}'
                                                : 'کاشڤان دیاری نەکراوە',
                                            style: AppTextStyles.caption.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],

                                  // Keepers info for physical warehouses
                                  if (!warehouse.isVan) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.badge_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            warehouse.keeperNames.isNotEmpty
                                                ? 'کارمەندانی کۆگا: ${warehouse.keeperNames.join("، ")}'
                                                : 'کارمەندی کۆگا: دیاری نەکراوە',
                                            style: AppTextStyles.caption,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],

                                  // Salesmen info for direct sales physical warehouses
                                  if (warehouse.isDirectSale) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.support_agent_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            warehouse.salesmanNames.isNotEmpty
                                                ? 'مەندوبەکانی فرۆشتن: ${warehouse.salesmanNames.join("، ")}'
                                                : 'مەندوبی تایبەت: دیاری نەکراوە (گشتی)',
                                            style: AppTextStyles.caption,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],

                                  Text(
                                    'ژمارەی جۆری کاڵاکان لە ستۆک: ${warehouse.stocksCount}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
