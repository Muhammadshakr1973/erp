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
      barrierDismissible: false,
      builder: (context) => _RouteFormDialog(route: route),
    );
  }

  void _showManageSalesmen(RouteModel route) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ManageSalesmenDialog(route: route),
    );
  }

  void _showRouteCustomers(RouteModel route) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RouteCustomersDialog(route: route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routesAsync = ref.watch(routeListProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('ڕاوتەکان (گەڕەکەکان)', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'ڕاوتی نوێ',
            onPressed: () => _showRouteForm(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بەڕێوەبردنی گەڕەکەکان، دیاریکردنی مەندوبەکان و بینینی کڕیارەکانی هەر ڕاوتێک.',
              style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                    return nameMatch;
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

                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (screenWidth >= 1024) {
                    crossAxisCount = 3;
                  } else if (screenWidth >= 600) {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 155,
                    ),
                    itemCount: filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      final routeColor = _parseColor(route.color) ?? theme.colorScheme.primary;

                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () => _showRouteForm(route),
                        onLongPress: () => _confirmDelete(route),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: routeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.alt_route, color: routeColor, size: 24),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        route.name,
                                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: route.isActive
                                              ? AppColors.success.withValues(alpha: 0.1)
                                              : AppColors.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          route.isActive ? 'چالاک' : 'ناچالاک',
                                          style: AppTextStyles.bodyBold.copyWith(
                                            color: route.isActive ? AppColors.success : AppColors.danger,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showRouteForm(route);
                                    } else if (value == 'salesmen') {
                                      _showManageSalesmen(route);
                                    } else if (value == 'customers') {
                                      _showRouteCustomers(route);
                                    } else if (value == 'delete') {
                                      _confirmDelete(route);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('دەستکاری ڕاوت', style: TextStyle(fontFamily: 'Rudaw', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'salesmen',
                                      child: Row(
                                        children: [
                                          Icon(Icons.badge_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('مەندوبەکان', style: TextStyle(fontFamily: 'Rudaw', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'customers',
                                      child: Row(
                                        children: [
                                          Icon(Icons.storefront, size: 18),
                                          SizedBox(width: 8),
                                          Text('کڕیارەکان', style: TextStyle(fontFamily: 'Rudaw', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('سڕینەوە', style: TextStyle(color: Colors.red, fontFamily: 'Rudaw', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () => _showRouteCustomers(route),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.storefront, size: 14, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${route.customersCount} کڕیار',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Rudaw',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _showManageSalesmen(route),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          route.salesmen.isEmpty
                                              ? 'مەندوب دیاری بکە'
                                              : route.salesmen.length == 1
                                                  ? route.salesmen.first.name
                                                  : '${route.salesmen.length} مەندوب',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Rudaw',
                                          ),
                                        ),
                                      ],
                                    ),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'بارکردنی ڕاوتەکان سەرکەوتوو نەبوو:\n${err.toString().replaceFirst('Exception: ', '')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Rudaw', color: Colors.red),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(routeListProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('دووبارە بارکردنەوە', style: TextStyle(fontFamily: 'Rudaw')),
                      ),
                    ],
                  ),
                ),
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
                    const SnackBar(content: Text('ڕاوت بە سەرکەوتوویی سڕایەوە', style: TextStyle(fontFamily: 'Rudaw'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('شکستی هێنا لە سڕینەوە: $e', style: const TextStyle(fontFamily: 'Rudaw'))),
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
    _color = widget.route?.color ?? '#122D5A';
    _isActive = widget.route?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          color: _color,
          isActive: _isActive,
        );
      } else {
        await actions.updateRoute(
          widget.route!.id,
          name: _nameController.text.trim(),
          color: _color,
          isActive: _isActive,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.route == null ? 'ڕاوت زیادکرا' : 'گۆڕانکارییەکان پاشەکەوت کران',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە لە پاشەکەوتکردن: $e', style: const TextStyle(fontFamily: 'Rudaw'))),
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSalesmen();
  }

  Future<void> _loadSalesmen() async {
    setState(() {
      _isLoadingSalesmen = true;
      _errorMessage = null;
    });
    try {
      final list = await ref.read(routeActionsProvider).fetchSalesmenList();
      setState(() {
        _salesmenList = list;
        _isLoadingSalesmen = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingSalesmen = false;
      });
    }
  }

  Future<void> _assign() async {
    if (_selectedSalesmanId == null) return;
    if (widget.route.salesmen.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ڕاوت ناتوانێت لە ١ مەندوب زیاتری هەبێت. تکایە سەرەتا مەندوبە کۆنەکە بسڕەوە.', style: TextStyle(fontFamily: 'Rudaw'))),
      );
      return;
    }
    setState(() => _isAssigning = true);

    try {
      await ref.read(routeActionsProvider).assignSalesman(
        widget.route.id,
        _selectedSalesmanId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مەندوب بەسەرکەوتوویی بۆ ڕاوتەکە دیاریکرا', style: TextStyle(fontFamily: 'Rudaw'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە: $e', style: const TextStyle(fontFamily: 'Rudaw'))),
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
          const SnackBar(content: Text('دیاریکردنی مەندوب سڕایەوە', style: TextStyle(fontFamily: 'Rudaw'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە: $e', style: const TextStyle(fontFamily: 'Rudaw'))),
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
            else if (_errorMessage != null)
              Column(
                children: [
                  Text('شکست لە هێنانی مەندوبەکان:\n$_errorMessage', style: const TextStyle(color: Colors.red, fontFamily: 'Rudaw')),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadSalesmen,
                    icon: const Icon(Icons.refresh),
                    label: const Text('دووبارە هەوڵبدەرەوە', style: TextStyle(fontFamily: 'Rudaw')),
                  ),
                ],
              )
            else if (_salesmenList.isEmpty)
              const Text('هیچ مەندوبێک لە سیستەمەکەدا بەردەست نییە.', style: TextStyle(color: Colors.grey, fontFamily: 'Rudaw'))
            else ...[
              DropdownButtonFormField<int>(
                value: _selectedSalesmanId,
                decoration: InputDecoration(
                  labelText: 'مەندوب هەڵبژێرە',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabled: widget.route.salesmen.isEmpty,
                ),
                items: _salesmenList.map((s) {
                  return DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text('${s['name']} (${s['phone'] ?? ''})', style: const TextStyle(fontFamily: 'Rudaw')),
                  );
                }).toList(),
                onChanged: widget.route.salesmen.isEmpty
                    ? (val) => setState(() => _selectedSalesmanId = val)
                    : null,
              ),
              if (widget.route.salesmen.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  '⚠️ ئەم ڕاوتە پێشتر مەندوبێکی بۆ دیاریکراوە. تکایە سەرەتا مەندوبەکەی پێشوو بسڕەوە.',
                  style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Rudaw'),
                ),
              ],
            ],

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
                    onPressed: _selectedSalesmanId == null || widget.route.salesmen.isNotEmpty ? null : _assign,
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await ref.read(routeActionsProvider).fetchRouteCustomers(widget.route.id);
      setState(() {
        _customers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
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
                  child: Text('کڕیارەکانی ڕاوتی ${widget.route.name} ', style: AppTextStyles.h2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('شکست لە هێنانی کڕیارەکان:\n$_errorMessage', style: const TextStyle(color: Colors.red, fontFamily: 'Rudaw')),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadCustomers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('دووبارە هەوڵبدەرەوە', style: TextStyle(fontFamily: 'Rudaw')),
                      ),
                    ],
                  ),
                ),
              )
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
