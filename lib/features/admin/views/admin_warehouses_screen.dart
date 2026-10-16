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

class AdminWarehousesScreen extends ConsumerStatefulWidget {
  const AdminWarehousesScreen({super.key});

  @override
  ConsumerState<AdminWarehousesScreen> createState() =>
      _AdminWarehousesScreenState();
}

class _AdminWarehousesScreenState extends ConsumerState<AdminWarehousesScreen> {
  String _selectedFilter = 'ALL'; // ALL, PHYSICAL, VAN
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
    final phoneController = TextEditingController(text: warehouse?.phone ?? '');
    bool isMain = warehouse?.isMain ?? false;
    bool isActive = warehouse?.isActive ?? true;
    String type = warehouse?.type ?? 'PHYSICAL';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                warehouse == null ? 'زیادکردنی کۆگای نوێ' : 'دەستکاریکردنی کۆگا',
                style: AppTextStyles.bodyBold,
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: nameController,
                        labelText: 'ناوی کۆگا *',
                        hintText: 'بۆ نموونە: کۆگای سەرەکی یان کاشڤان - هەژار',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'جۆری کۆگا',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PHYSICAL',
                            child: Row(
                              children: [
                                Icon(Icons.warehouse_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('کۆگای فیزیایی (لق / سەرەکی)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'VAN',
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('ئۆتۆمبێلی کاشڤان (گەڕۆک)'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              type = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: addressController,
                        labelText: 'ناونیشان / شوێن',
                        hintText: type == 'VAN'
                            ? 'ژمارەی ئۆتۆمبێل یان ناوچە'
                            : 'ناونیشانی فیزیکی کۆگا',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: phoneController,
                        labelText: 'ژمارەی مۆبایل / پەیوەندی',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
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
                      if (warehouse != null)
                        SwitchListTile(
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
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('پاشگەزبوونەوە'),
                ),
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

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final actions =
                                ref.read(warehouseAdminActionsProvider);
                            if (warehouse == null) {
                              await actions.createWarehouse(
                                name: name,
                                address: addressController.text.trim(),
                                phone: phoneController.text.trim(),
                                isMain: isMain,
                                type: type,
                              );
                            } else {
                              await actions.updateWarehouse(
                                id: warehouse.id,
                                name: name,
                                address: addressController.text.trim(),
                                phone: phoneController.text.trim(),
                                isMain: isMain,
                                isActive: isActive,
                                type: type,
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
                                    e.toString().replaceAll('Exception: ', ''),
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
  }

  void _showDeleteDialog(WarehouseModel warehouse) {
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('سڕینەوەی کۆگای ${warehouse.name}'),
              content: const Text(
                'ئایا دڵنیایت لە سڕینەوەی ئەم کۆگایە؟\nتێبینی: ئەگەر کۆگاکە هەر کاڵایەکی تێدا مابێت سڕینەوەکە ڕەتدەکرێتەوە تاوەکو کاڵاکان بەتاڵ دەکرێن.',
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('پاشگەزبوونەوە'),
                ),
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
                                    e.toString().replaceAll('Exception: ', ''),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWarehouseFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('کۆگای نوێ'),
      ),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'کێشەیەک ڕوویدا لە بارکردنی کۆگاکان',
            message: Formatters.cleanError(err),
            retryText: 'دووبارە هەوڵبدەرەوە',
            onRetry: () => ref.invalidate(warehouseListProvider),
          ),
        ),
        data: (warehouses) {
          final physicalCount = warehouses.where((w) => !w.isVan).length;
          final vanCount = warehouses.where((w) => w.isVan).length;

          final filtered = warehouses.where((w) {
            if (_selectedFilter == 'PHYSICAL' && w.isVan) return false;
            if (_selectedFilter == 'VAN' && !w.isVan) return false;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesName = w.name.toLowerCase().contains(q);
              final matchesAddress =
                  w.address?.toLowerCase().contains(q) ?? false;
              final matchesPhone = w.phone?.toLowerCase().contains(q) ?? false;
              return matchesName || matchesAddress || matchesPhone;
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(warehouseListProvider);
              await ref.read(warehouseListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                // 1. Stats Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('کۆی کۆگاکان',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(
                                  '${warehouses.length}',
                                  style: AppTextStyles.h2.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('کۆگای فیزیایی',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(
                                  '$physicalCount',
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ئۆتۆمبێلی کاشڤان',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text(
                                  '$vanCount',
                                  style: AppTextStyles.h2.copyWith(
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Search & Filter Bar
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _searchController,
                        hintText: 'گەڕان بەپێی ناوی کۆگا یان ناونیشان...',
                        prefixIcon: Icons.search,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ALL', label: Text('هەموو')),
                        ButtonSegment(
                            value: 'PHYSICAL', label: Text('فیزیایی')),
                        ButtonSegment(value: 'VAN', label: Text('کاشڤان')),
                      ],
                      selected: {_selectedFilter},
                      onSelectionChanged: (set) {
                        setState(() {
                          _selectedFilter = set.first;
                        });
                      },
                    ),
                  ],
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: warehouse.isVan
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                warehouse.isVan
                                    ? Icons.local_shipping_outlined
                                    : Icons.warehouse_outlined,
                                color: warehouse.isVan
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          warehouse.name,
                                          style: AppTextStyles.bodyBold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (warehouse.isMain) ...[
                                        const SizedBox(width: 8),
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
                                            'سەرەکی',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (warehouse.isVan) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.orange
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: const Text(
                                            'کاشڤان',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    warehouse.address != null &&
                                            warehouse.address!.isNotEmpty
                                        ? warehouse.address!
                                        : (warehouse.isVan
                                            ? 'ئۆتۆمبێلی گەڕۆکی مەندوب'
                                            : 'ناونیشان دیاری نەکراوە'),
                                    style: AppTextStyles.caption,
                                  ),
                                  if (warehouse.phone != null &&
                                      warehouse.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'پەیوەندی: ${warehouse.phone}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontFamily: 'KJino',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'دەستکاریکردن',
                                  onPressed: () =>
                                      _showWarehouseFormDialog(warehouse),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.danger),
                                  tooltip: 'سڕینەوە',
                                  onPressed: () =>
                                      _showDeleteDialog(warehouse),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
