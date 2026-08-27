import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/models/route_model.dart';
import '../../shared/providers/route_provider.dart';

class AdminRoutesScreen extends ConsumerStatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  ConsumerState<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends ConsumerState<AdminRoutesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRouteForm([RouteModel? route]) {
    showDialog(
      context: context,
      builder: (context) => _RouteFormDialog(route: route),
    );
  }

  void _showManageSalesmen(RouteModel route) {
    showDialog(
      context: context,
      builder: (context) => _ManageSalesmenDialog(route: route),
    );
  }

  void _showRouteCustomers(RouteModel route) {
    showDialog(
      context: context,
      builder: (context) => _RouteCustomersDialog(route: route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routesAsync = ref.watch(routeListProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بەڕێوەبردنی ڕاوتەکان (گەڕەکەکان)', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        'بەڕێوەبردنی گەڕەکەکان، دیاریکردنی مەندوبەکان و بینینی کڕیارەکانی هەر ڕاوتێک.',
                        style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 220,
                  child: AppButton(
                    text: 'زیادکردنی ڕاوتی نوێ',
                    icon: Icons.add_location_alt_outlined,
                    onPressed: () => _showRouteForm(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Overview Stats
            routesAsync.maybeWhen(
              data: (routes) {
                final totalRoutes = routes.length;
                final activeRoutes = routes.where((r) => r.isActive).length;
                final totalCustomers = routes.fold<int>(0, (sum, r) => sum + r.customersCount);
                final totalSalesmenAssigned = routes.fold<int>(0, (sum, r) => sum + r.salesmen.length);

                return Row(
                  children: [
                    Expanded(child: _buildStatCard('کۆی ڕاوتەکان', '$totalRoutes', Icons.alt_route, theme.colorScheme.primary)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildStatCard('ڕاوتی چالاک', '$activeRoutes', Icons.check_circle_outline, AppColors.success)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildStatCard('کۆی کڕیارەکان', '$totalCustomers', Icons.storefront, AppColors.info)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildStatCard('مەندوبە دابەشکراوەکان', '$totalSalesmenAssigned', Icons.badge_outlined, AppColors.warning)),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Search Bar
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      labelText: 'گەڕان بەدوای ڕاوتدا...',
                      prefixIcon: Icons.search,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Route List / Grid
            Expanded(
              child: routesAsync.when(
                data: (routes) {
                  final filteredRoutes = routes.where((r) {
                    final nameMatch = r.name.toLowerCase().contains(_searchQuery);
                    final codeMatch = r.code.toLowerCase().contains(_searchQuery);
                    return nameMatch || codeMatch;
                  }).toList();

                  if (filteredRoutes.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alt_route, size: 64, color: Colors.grey),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'هیچ ڕاوتێک نەدۆزرایەوە',
                            style: AppTextStyles.bodyBold,
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 240,
                    ),
                    itemCount: filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      final routeColor = _parseColor(route.color) ?? theme.colorScheme.primary;

                      return AppCard(
                        color: routeColor.withValues(alpha: 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: routeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: routeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    route.code,
                                    style: TextStyle(
                                      color: routeColor,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Rudaw',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    route.name,
                                    style: AppTextStyles.bodyBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _showRouteForm(route);
                                    } else if (val == 'salesmen') {
                                      _showManageSalesmen(route);
                                    } else if (val == 'customers') {
                                      _showRouteCustomers(route);
                                    } else if (val == 'delete') {
                                      _confirmDelete(route);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('دەستکاریکردن', style: TextStyle(fontFamily: 'Rudaw')),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'salesmen',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_add_alt_outlined, size: 20, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('دیاریکردنی مەندوب', style: TextStyle(fontFamily: 'Rudaw')),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'customers',
                                      child: Row(
                                        children: [
                                          Icon(Icons.storefront_outlined, size: 20, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('بینینی کڕیارەکان', style: TextStyle(fontFamily: 'Rudaw')),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('سڕینەوە', style: TextStyle(color: Colors.red, fontFamily: 'Rudaw')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              route.description ?? 'هیچ ڕوونکردنەوەیەک نییە',
                              style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),

                            // Badges for customers & assigned salesmen
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => _showRouteCustomers(route),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storefront, size: 14, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${route.customersCount} کڕیار',
                                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Rudaw'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                InkWell(
                                  onTap: () => _showManageSalesmen(route),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.badge, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          route.salesmen.isEmpty
                                              ? 'دیاریکردنی مەندوب'
                                              : '${route.salesmen.length} مەندوب',
                                          style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Rudaw'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  route.isActive ? '● چالاکە' : '○ ناچالاکە',
                                  style: TextStyle(
                                    color: route.isActive ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                    fontFamily: 'Rudaw',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showManageSalesmen(route),
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: const Text('دیاریکردنی مەندوب', style: TextStyle(fontSize: 12, fontFamily: 'Rudaw')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('کێشە: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Rudaw')),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Rudaw')),
            ],
          ),
        ],
      ),
    );
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (colorStr.length == 6 || colorStr.length == 7) buffer.write('ff');
      buffer.write(colorStr.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  void _confirmDelete(RouteModel route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دڵنیایی لە سڕینەوە', style: TextStyle(fontFamily: 'Rudaw')),
        content: Text('ئایا دڵنیای لە سڕینەوەی ڕاوتی "${route.name}"؟', style: const TextStyle(fontFamily: 'Rudaw')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە', style: TextStyle(fontFamily: 'Rudaw')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(routeActionsProvider).deleteRoute(route.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ڕاوت بە سەرکەوتوویی سڕایەوە')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('شکستی هێنا لە سڕینەوە: $e')),
                  );
                }
              }
            },
            child: const Text('سڕینەوە', style: TextStyle(color: Colors.white, fontFamily: 'Rudaw')),
          ),
        ],
      ),
    );
  }
}

class _RouteFormDialog extends ConsumerStatefulWidget {
  final RouteModel? route;

  const _RouteFormDialog({this.route});

  @override
  ConsumerState<_RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends ConsumerState<_RouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  String _color = '#122D5A';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _colors = [
    '#122D5A', // Navy
    '#0A9C6E', // Green
    '#D4820A', // Orange
    '#93535D', // Crimson
    '#7B41D6', // Purple
    '#2678D4', // Blue
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.route?.name);
    _codeController = TextEditingController(text: widget.route?.code);
    _descriptionController = TextEditingController(text: widget.route?.description);
    _color = widget.route?.color ?? '#122D5A';
    _isActive = widget.route?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(routeActionsProvider);
      if (widget.route == null) {
        await actions.addRoute(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          color: _color,
          isActive: _isActive,
        );
      } else {
        await actions.updateRoute(
          widget.route!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          color: _color,
          isActive: _isActive,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.route == null ? 'ڕاوت زیادکرا' : 'گۆڕانکارییەکان پاشەکەوت کران'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە لە پاشەکەوتکردن: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.route == null ? 'زیادکردنی ڕاوتی نوێ' : 'دەستکاری ڕاوت',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameController,
                labelText: 'ناوی ڕاوت / گەڕەک',
                hintText: 'بۆ نموونە: گەڕەکی ڕزگاری',
                prefixIcon: Icons.alt_route,
                validator: (val) => val == null || val.isEmpty ? 'تکایە ناوی ڕاوت بنووسە' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _codeController,
                labelText: 'کۆدی ڕاوت',
                hintText: 'بۆ نموونە: R-RZ',
                prefixIcon: Icons.code,
                validator: (val) => val == null || val.isEmpty ? 'تکایە کۆدی ڕاوت بنووسە' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descriptionController,
                labelText: 'ڕوونکردنەوە (ئارەزوومەندانە)',
                hintText: 'وردەکاری ڕاوت...',
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('ڕەنگی هێما', style: AppTextStyles.bodyBold),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors.map((c) {
                  final parsedColor = _parseColor(c)!;
                  final isSelected = _color == c;

                  return InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: parsedColor,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                value: _isActive,
                title: const Text('دۆخی ڕاوت', style: AppTextStyles.bodyBold),
                subtitle: const Text('ڕێگەدان بە مەندوب بۆ کارکردن لەسەر ئەم ڕاوتە', style: TextStyle(fontSize: 12, fontFamily: 'Rudaw')),
                activeColor: theme.colorScheme.primary,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('پاشگەزبوونەوە', style: TextStyle(fontFamily: 'Rudaw')),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 120,
                    child: AppButton(
                      text: 'پاشەکەوت',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (colorStr.length == 6 || colorStr.length == 7) buffer.write('ff');
      buffer.write(colorStr.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}

class _ManageSalesmenDialog extends ConsumerStatefulWidget {
  final RouteModel route;

  const _ManageSalesmenDialog({required this.route});

  @override
  ConsumerState<_ManageSalesmenDialog> createState() => _ManageSalesmenDialogState();
}

class _ManageSalesmenDialogState extends ConsumerState<_ManageSalesmenDialog> {
  int? _selectedSalesmanId;
  List<Map<String, dynamic>> _salesmenList = [];
  bool _isLoadingSalesmen = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadSalesmen();
  }

  Future<void> _loadSalesmen() async {
    try {
      final list = await ref.read(routeActionsProvider).fetchSalesmenList();
      setState(() {
        _salesmenList = list;
        _isLoadingSalesmen = false;
      });
    } catch (e) {
      setState(() => _isLoadingSalesmen = false);
    }
  }

  Future<void> _assign() async {
    if (_selectedSalesmanId == null) return;
    setState(() => _isAssigning = true);

    try {
      await ref.read(routeActionsProvider).assignSalesman(
        widget.route.id,
        _selectedSalesmanId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مەندوب بەسەرکەوتوویی بۆ ڕاوتەکە دیاریکرا')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _remove(int salesmanId) async {
    try {
      await ref.read(routeActionsProvider).removeSalesman(
        widget.route.id,
        salesmanId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دیاریکردنی مەندوب سڕایەوە')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.badge, color: AppColors.info),
                const SizedBox(width: 8),
                Text('دیاریکردنی مەندوب بۆ ڕاوتی ${widget.route.name}', style: AppTextStyles.h2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Currently Assigned Salesmen
            const Text('مەندوبە چالاکەکانی ئەم ڕاوتە:', style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.xs),

            if (widget.route.salesmen.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('هیچ مەندوبێک بۆ ئەم ڕاوتە دیاری نەکراوە.', style: TextStyle(color: Colors.grey, fontFamily: 'Rudaw')),
              )
            else
              Column(
                children: widget.route.salesmen.map((s) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rudaw')),
                      subtitle: Text(s.phone ?? '', style: const TextStyle(fontFamily: 'Rudaw')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _remove(s.salesmanId),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const Divider(height: 24),

            const Text('دیاریکردنی مەندوبی نوێ:', style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.xs),

            if (_isLoadingSalesmen)
              const Center(child: CircularProgressIndicator())
            else if (_salesmenList.isEmpty)
              const Text('هیچ مەندوبێک لە سیستەمەکەدا بەردەست نییە.', style: TextStyle(color: Colors.grey, fontFamily: 'Rudaw'))
            else
              DropdownButtonFormField<int>(
                value: _selectedSalesmanId,
                decoration: InputDecoration(
                  labelText: 'مەندوب هەڵبژێرە',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _salesmenList.map((s) {
                  return DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text('${s['name']} (${s['phone'] ?? ''})', style: const TextStyle(fontFamily: 'Rudaw')),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSalesmanId = val),
              ),

            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('داخستن', style: TextStyle(fontFamily: 'Rudaw')),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 120,
                  child: AppButton(
                    text: 'دیاریکردن',
                    isLoading: _isAssigning,
                    onPressed: _selectedSalesmanId == null ? null : _assign,
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

class _RouteCustomersDialog extends ConsumerStatefulWidget {
  final RouteModel route;

  const _RouteCustomersDialog({required this.route});

  @override
  ConsumerState<_RouteCustomersDialog> createState() => _RouteCustomersDialogState();
}

class _RouteCustomersDialogState extends ConsumerState<_RouteCustomersDialog> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await ref.read(routeActionsProvider).fetchRouteCustomers(widget.route.id);
      setState(() {
        _customers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('کڕیارەکانی ڕاوتی ${widget.route.name} (${widget.route.code})', style: AppTextStyles.h2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_customers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('هیچ کڕیارێک لەم ڕاوتەدا تۆمار نەکراوە.', style: TextStyle(color: Colors.grey, fontFamily: 'Rudaw')),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    final balance = c['current_balance'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.success.withValues(alpha: 0.1),
                          child: const Icon(Icons.store, color: AppColors.success),
                        ),
                        title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rudaw')),
                        subtitle: Text('${c['phone'] ?? ''} - ${c['address'] ?? 'بێ ناونیشان'}', style: const TextStyle(fontFamily: 'Rudaw')),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('قەرز:', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Rudaw')),
                            Text(
                              '$balance دینار',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.green,
                                fontFamily: 'Rudaw',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('داخستن', style: TextStyle(fontFamily: 'Rudaw')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
