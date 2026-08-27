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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بەڕێوەبردنی ڕاوتەکان (گەڕەکەکان)', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'لێرەوە دەتوانیت گەڕەک و ڕاوتی نوێ زیاد بکەیت یان دەستکارییان بکەیت.',
                      style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                AppButton(
                  text: 'زیادکردنی ڕاوت',
                  icon: Icons.add,
                  onPressed: () => _showRouteForm(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
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
                      maxCrossAxisExtent: 400,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      final routeColor = _parseColor(route.color) ?? theme.colorScheme.primary;

                      return AppCard(
                        color: routeColor.withValues(alpha: 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: routeColor.withValues(alpha: 0.1),
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
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                route.description ?? 'هیچ ڕوونکردنەوەیەک نییە',
                                style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  route.isActive ? 'چالاکە' : 'ناچالاکە',
                                  style: TextStyle(
                                    color: route.isActive ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                    fontFamily: 'Rudaw',
                                    fontWeight: FontWeight.bold,
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
                error: (err, _) => Center(child: Text('کێشە: $err')),
              ),
            ),
          ],
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
