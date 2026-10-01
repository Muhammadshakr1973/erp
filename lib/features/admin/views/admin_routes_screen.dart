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
import '../../shared/providers/customer_provider.dart';

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Stats
            routesAsync.maybeWhen(
              data: (routes) {
                final totalRoutes = routes.length;
                final totalCustomers = routes.fold<int>(
                  0,
                  (sum, r) => sum + r.customersCount,
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 720;
                    final spacing = isCompact ? AppSpacing.sm : AppSpacing.md;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'کۆی ڕاوتەکان',
                            '$totalRoutes',
                            Icons.alt_route,
                            theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: _buildStatCard(
                            'کۆی کڕیارەکان',
                            '$totalCustomers',
                            Icons.storefront,
                            AppColors.info,
                          ),
                        ),
                      ],
                    );
                  },
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
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(routeListProvider),
                child: routesAsync.when(
                  data: (routes) {
                    final filteredRoutes = routes.where((r) {
                      final nameMatch = r.name.toLowerCase().contains(
                        _searchQuery,
                      );
                      return nameMatch;
                    }).toList();
  
                    if (filteredRoutes.isEmpty) {
                      return LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: const Center(
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
                            ),
                          ),
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
  
                    if (crossAxisCount == 1) {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredRoutes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          return _buildRouteCard(
                            context,
                            filteredRoutes[index],
                            theme,
                          );
                        },
                      );
                    }
  
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.sm,
                        mainAxisExtent: 116,
                      ),
                      itemCount: filteredRoutes.length,
                      itemBuilder: (context, index) {
                        return _buildRouteCard(
                          context,
                          filteredRoutes[index],
                          theme,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'بارکردنی ڕاوتەکان سەرکەوتوو نەبوو:\n${err.toString().replaceFirst('Exception: ', '')}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Rudaw',
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: () => ref.invalidate(routeListProvider),
                                icon: const Icon(Icons.refresh),
                                label: const Text(
                                  'دووبارە بارکردنەوە',
                                  style: TextStyle(fontFamily: 'Rudaw'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    RouteModel route,
    ThemeData theme,
  ) {
    final routeColor =
        _parseColor(route.color) ?? theme.colorScheme.primary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showRouteForm(route),
      onLongPress: () => _confirmDelete(route),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: routeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.alt_route,
                    color: routeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: route.isActive
                              ? AppColors.success.withValues(
                                  alpha: 0.1,
                                )
                              : AppColors.danger.withValues(
                                  alpha: 0.1,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          route.isActive ? 'چالاک' : 'ناچالاک',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: route.isActive
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showRouteCustomers(route),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront,
                        size: 14,
                        color: Colors.green,
                      ),
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
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showManageSalesmen(route),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.blue,
                      ),
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
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontFamily: 'Rudaw',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Rudaw',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'دڵنیایی لە سڕینەوە',
                style: TextStyle(fontFamily: 'Rudaw'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(
          'ئایا دڵنیای لە سڕینەوەی ڕاوتی "${route.name}"؟',
          style: const TextStyle(fontFamily: 'Rudaw'),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            onPressed: () async {
              try {
                await ref.read(routeActionsProvider).deleteRoute(route.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ڕاوت بە سەرکەوتوویی سڕایەوە',
                        style: TextStyle(fontFamily: 'Rudaw'),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'شکستی هێنا لە سڕینەوە: $e',
                        style: const TextStyle(fontFamily: 'Rudaw'),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'سڕینەوە',
              style: TextStyle(fontFamily: 'Rudaw'),
            ),
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
              widget.route == null
                  ? 'ڕاوت زیادکرا'
                  : 'گۆڕانکارییەکان پاشەکەوت کران',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'کێشە لە پاشەکەوتکردن: $e',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
          ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.route == null ? 'زیادکردنی ڕاوتی نوێ' : 'دەستکاری ڕاوت',
                      style: AppTextStyles.h2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameController,
                labelText: 'ناوی ڕاوت / گەڕەک',
                hintText: 'بۆ نموونە: گەڕەکی ڕزگاری',
                prefixIcon: Icons.alt_route,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'تکایە ناوی ڕاوت بنووسە';
                  }
                  final trimmedVal = val.trim().toLowerCase();
                  final routes = ref.read(routeListProvider).value ?? [];
                  final isDuplicate = routes.any((r) {
                    if (widget.route != null && r.id == widget.route!.id) {
                      return false;
                    }
                    return r.name.trim().toLowerCase() == trimmedVal;
                  });
                  if (isDuplicate) {
                    return 'ئەم ناوی ڕاوتە پێشتر تۆمارکراوە';
                  }
                  return null;
                },
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
                subtitle: const Text(
                  'ڕێگەدان بە مەندوب بۆ کارکردن لەسەر ئەم ڕاوتە',
                  style: TextStyle(fontSize: 12, fontFamily: 'Rudaw'),
                ),
                activeColor: theme.colorScheme.primary,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'پاشەکەوت',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
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
  ConsumerState<_ManageSalesmenDialog> createState() =>
      _ManageSalesmenDialogState();
}

class _ManageSalesmenDialogState extends ConsumerState<_ManageSalesmenDialog> {
  List<Map<String, dynamic>> _salesmenList = [];
  bool _isLoadingSalesmen = true;
  bool _isAssigning = false;
  String? _errorMessage;

  final List<Map<String, String>> _daysOfWeek = [
    {'key': 'Saturday', 'label': 'ڕۆژی شەممە'},
    {'key': 'Sunday', 'label': 'ڕۆژی یەکشەممە'},
    {'key': 'Monday', 'label': 'ڕۆژی دووشەممە'},
    {'key': 'Tuesday', 'label': 'ڕۆژی سێشەممە'},
    {'key': 'Wednesday', 'label': 'ڕۆژی چوارشەممە'},
    {'key': 'Thursday', 'label': 'ڕۆژی پێنجشەممە'},
    {'key': 'Friday', 'label': 'ڕۆژی جومعە'},
  ];

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

  Future<void> _assignDay(String dayKey, int salesmanId) async {
    setState(() => _isAssigning = true);

    try {
      await ref
          .read(routeActionsProvider)
          .assignSalesman(widget.route.id, salesmanId, dayOfWeek: dayKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'مەندوب بەسەرکەوتوویی بۆ ئەم ڕۆژە دیاریکرا',
              style: TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'کێشە: $e',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _removeDay(int salesmanId, String dayKey) async {
    try {
      await ref
          .read(routeActionsProvider)
          .removeSalesman(widget.route.id, salesmanId, dayOfWeek: dayKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'دیاریکردنی مەندوب بۆ ئەم ڕۆژە سڕایەوە',
              style: TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'کێشە: $e',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'پلانی هەفتانەی ڕاوتی ${widget.route.name}',
                      style: AppTextStyles.h2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'مەندوب بۆ هەر ڕۆژێکی هەفتە دیاری بکە:',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              
              if (_isLoadingSalesmen)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Column(
                  children: [
                    Text(
                      'شکست لە هێنانی لیستی مەندوبەکان:\n$_errorMessage',
                      style: const TextStyle(color: Colors.red, fontFamily: 'Rudaw'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadSalesmen,
                      icon: const Icon(Icons.refresh),
                      label: const Text('دووبارە هەوڵبدەرەوە', style: TextStyle(fontFamily: 'Rudaw')),
                    ),
                  ],
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _daysOfWeek.length,
                  separatorBuilder: (context, index) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final day = _daysOfWeek[index];
                    
                    AssignedSalesmanInfo? assignedSalesman;
                    for (var s in widget.route.salesmen) {
                      if (s.dayOfWeek == day['key']) {
                        assignedSalesman = s;
                        break;
                      }
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          // Day Label
                          SizedBox(
                            width: 120,
                            child: Text(
                              day['label']!,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Assignment details or Dropdown
                          Expanded(
                            child: assignedSalesman != null
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              assignedSalesman.name,
                                              style: AppTextStyles.bodyBold,
                                            ),
                                            if (assignedSalesman.phone != null)
                                              Text(
                                                assignedSalesman.phone!,
                                                style: AppTextStyles.caption,
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _removeDay(assignedSalesman!.salesmanId, day['key']!),
                                        tooltip: 'سڕینەوەی مەندوب',
                                      ),
                                    ],
                                  )
                                : _salesmenList.isEmpty
                                    ? const Text(
                                        'هیچ مەندوبێک نییە',
                                        style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Rudaw'),
                                      )
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          hint: const Text(
                                            'مەندوبێک دیاری بکە',
                                            style: TextStyle(fontSize: 12, fontFamily: 'Rudaw', color: Colors.grey),
                                          ),
                                          isDense: true,
                                          items: _salesmenList.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s['id'],
                                              child: Text(
                                                s['name'],
                                                style: const TextStyle(fontSize: 13, fontFamily: 'Rudaw'),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _isAssigning
                                              ? null
                                              : (val) {
                                                  if (val != null) {
                                                    _assignDay(day['key']!, val);
                                                  }
                                                },
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  text: 'داخستن',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCustomersDialog extends ConsumerStatefulWidget {
  final RouteModel route;

  const _RouteCustomersDialog({required this.route});

  @override
  ConsumerState<_RouteCustomersDialog> createState() =>
      _RouteCustomersDialogState();
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
      final list = await ref
          .read(routeActionsProvider)
          .fetchRouteCustomers(widget.route.id);
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

  Future<void> _showAssignCustomersDialog() async {
    final customersAsync = ref.read(customerListProvider);
    List<int> selectedIds = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'دیاریکردنی کڕیار بۆ ئەم ڕاوتە',
                    style: AppTextStyles.h3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 350,
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('کێشە لە هێنانی کڕیارەکان: $err')),
                data: (allCustomers) {
                  final assignable = allCustomers
                      .where((c) => c.routeId != widget.route.id)
                      .toList();

                  if (assignable.isEmpty) {
                    return const Center(
                      child: Text(
                        'هیچ کڕیارێکی تر بەردەست نییە بۆ دیاریکردن.',
                        style: TextStyle(fontFamily: 'Rudaw'),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: assignable.length,
                    itemBuilder: (context, index) {
                      final c = assignable[index];
                      final isSelected = selectedIds.contains(c.id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Rudaw',
                          ),
                        ),
                        subtitle: Text(
                          c.phone ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Rudaw',
                          ),
                        ),
                        onChanged: (val) {
                          setStateDialog(() {
                            if (val == true) {
                              selectedIds.add(c.id);
                            } else {
                              selectedIds.remove(c.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(routeActionsProvider)
                              .assignCustomers(widget.route.id, selectedIds);
                          Navigator.pop(context);
                          _loadCustomers();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'کێشە: $e',
                                style: const TextStyle(fontFamily: 'Rudaw'),
                              ),
                            ),
                          );
                        }
                      },
                child: const Text(
                  'دیاریکردن',
                  style: TextStyle(fontFamily: 'Rudaw'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        height: 550,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'کڕیارەکانی ڕاوتی ${widget.route.name}',
                    style: AppTextStyles.h2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_link, color: AppColors.info),
                  tooltip: 'زیادکردنی کڕیار بۆ ئەم ڕاوتە',
                  onPressed: _showAssignCustomersDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'دەتوانیت کڕیارەکان ڕابکێشیت (Drag) بۆ دەستکاریکردنی ڕیزبەندی سەردانیان.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'Rudaw',
              ),
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
                      Text(
                        'شکست لە هێنانی کڕیارەکان:\n$_errorMessage',
                        style: const TextStyle(
                          color: Colors.red,
                          fontFamily: 'Rudaw',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadCustomers,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'دووبارە هەوڵبدەرەوە',
                          style: TextStyle(fontFamily: 'Rudaw'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_customers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'هیچ کڕیارێک لەم ڕاوتەدا تۆمار نەکراوە.',
                    style: TextStyle(color: Colors.grey, fontFamily: 'Rudaw'),
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _customers.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    setState(() {
                      final item = _customers.removeAt(oldIndex);
                      _customers.insert(newIndex, item);
                    });

                    try {
                      final ids = _customers
                          .map<int>((c) => c['id'] as int)
                          .toList();
                      await ref
                          .read(routeActionsProvider)
                          .reorderCustomers(widget.route.id, ids);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ڕیزبەندی نوێی سەردانەکان پاشەکەوت کرا',
                            style: TextStyle(fontFamily: 'Rudaw'),
                          ),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'سەرکەوتوو نەبوو لە نوێکردنەوەی ڕیزبەندی: $e',
                            style: const TextStyle(fontFamily: 'Rudaw'),
                          ),
                        ),
                      );
                      _loadCustomers();
                    }
                  },
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    final balance = c['current_balance'] ?? 0;

                    return Card(
                      key: ValueKey(c['id']),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.success.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Rudaw',
                          ),
                        ),
                        subtitle: Text(
                          '${c['phone'] ?? ''} - ${c['address'] ?? 'بێ ناونیشان'}',
                          style: const TextStyle(fontFamily: 'Rudaw'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'قەرز:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontFamily: 'Rudaw',
                                  ),
                                ),
                                Text(
                                  '$balance دینار',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontFamily: 'Rudaw',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.drag_handle, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
