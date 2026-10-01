import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pos_app/features/products/utils/barcode_helper.dart';

import 'dart:math';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/components/error_state.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/components/customer_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/providers/warehouse_provider.dart';
import '../../shared/providers/route_provider.dart';
import 'providers/user_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
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

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'خاوەن کار';
      case 'admin':
        return 'بەڕێوەبەر';
      case 'salesman':
        return 'مەندوب';
      case 'warehouse':
        return 'کۆگادار';
      case 'driver':
        return 'شۆفێر';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role, ThemeData theme) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.red;
      case 'admin':
        return theme.colorScheme.primary;
      case 'salesman':
        return Colors.orange;
      case 'warehouse':
        return Colors.brown;
      case 'driver':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showUserFormDialog(
    BuildContext context, [
    UserModel? user,
    List<dynamic>? roles,
  ]) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(user: user, roles: roles),
    );
  }

  void _showDeleteUserDialog(BuildContext context, UserModel user) {
    final currentUser = ref.read(authProvider).user;
    if (currentUser != null && currentUser.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ ناتوانیت هەژماری خۆت بسڕیتەوە!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('سڕینەوەی بەکارهێنەر', style: AppTextStyles.h3),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text('دڵنیایت لە سڕینەوەی بەکارهێنەر "${user.name}"؟'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            onPressed: () async {
              try {
                await ref.read(userActionsProvider).deleteUser(user.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('بەکارهێنەر بە سەرکەوتوویی سڕایەوە'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('کێشە: $e')));
                }
              }
            },
            child: const Text('بسڕەوە', style: TextStyle(fontFamily: 'Rudaw')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(userAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بەکارهێنەرانی سیستەم', style: AppTextStyles.h1),
        actions: [
          usersAsync.when(
            data: (data) {
              final roles = data['roles'] as List<dynamic>?;
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'بەکارهێنەری نوێ',
                onPressed: () => _showUserFormDialog(context, null, roles),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),

      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText:
                        'گەڕان بەدوای بەکارهێنەر (ناو، مۆبایل، ئیمەیڵ)...',
                    prefixIcon: Icons.search,
                  ),
                ),
              ],
            ),
          ),

          // User Grid / List
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: ErrorState(
                  title: 'هەڵەیەک ڕوویدا',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () => ref.invalidate(userAdminProvider),
                ),
              ),
              data: (data) {
                final List<UserModel> users = data['users'] ?? [];
                final List<dynamic> roles = data['roles'] ?? [];

                final filteredUsers = users.where((u) {
                  final nameMatch = u.name.toLowerCase().contains(_searchQuery);
                  final phoneMatch = u.phone.toLowerCase().contains(
                    _searchQuery,
                  );
                  return nameMatch || phoneMatch;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          'هیچ بەکارهێنەرێک نەدۆزرایەوە',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: 92,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final roleColor = _getRoleColor(user.role, theme);

                    return AppCard(
                      onTap: () => _showUserFormDialog(context, user, roles),
                      onLongPress: () => _showDeleteUserDialog(context, user),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          CustomerAvatar(
                            imageUrl: user.imageUrl,
                            size: 48,
                            borderRadius: 14,
                            placeholderIcon: user.role.toLowerCase() == 'salesman'
                                ? Icons.badge_outlined
                                : user.role.toLowerCase() == 'admin' ||
                                      user.role.toLowerCase() == 'owner'
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline,
                            backgroundColor: roleColor.withValues(alpha: 0.1),
                            iconColor: roleColor,
                            iconSize: 26,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.name,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'تەلەفۆن: ${user.phone}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (user.role.toLowerCase() == 'salesman') ...[
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if ((user.fixedSalary ?? 0) > 0)
                                        Text(
                                          'سابت: ${Formatters.currency(user.fixedSalary ?? 0)}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      if (user.commissionRate != null &&
                                          user.commissionRate! > 0)
                                        Text(
                                          'کۆمسیۆن: ${user.commissionRate}%',
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ] else if ((user.fixedSalary ?? 0) > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'مووچەی سابت: ${Formatters.currency(user.fixedSalary ?? 0)}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: roleColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _getRoleDisplayName(user.role),
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    fontFamily: 'Rudaw',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (user.isActive ?? true)
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (user.isActive ?? true)
                                      ? 'چالاک'
                                      : 'ناچالاک',
                                  style: TextStyle(
                                    color: (user.isActive ?? true)
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rudaw',
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
            ),
          ),
        ],
      ),
    );
  }
}

class UserFormDialog extends ConsumerStatefulWidget {
  final UserModel? user;
  final List<dynamic>? roles;

  const UserFormDialog({super.key, this.user, this.roles});

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _phoneKey = GlobalKey();
  final GlobalKey _passwordKey = GlobalKey();
  final GlobalKey _roleKey = GlobalKey();
  final GlobalKey _salaryKey = GlobalKey();
  final GlobalKey _commissionKey = GlobalKey();
  final GlobalKey _warehouseKey = GlobalKey();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _commissionRateController;
  late final TextEditingController _fixedSalaryController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _imageUrlController;

  int? _selectedRoleId;
  int? _selectedWarehouseId;
  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _phoneError;

  String _selectedRoutingCycle = '1_week';
  Map<String, int?> _routeAssignments = {}; // Key: 'weekNumber_dayOfWeek', Value: routeId

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name);
    _phoneController = TextEditingController(text: widget.user?.phone);
    _passwordController = TextEditingController();
    _commissionRateController = TextEditingController(
      text: widget.user?.commissionRate != null
          ? widget.user!.commissionRate!.toString()
          : '',
    );
    _fixedSalaryController = TextEditingController(
      text: widget.user?.fixedSalary != null && widget.user!.fixedSalary != 0
          ? widget.user!.fixedSalary!.toString()
          : '',
    );
    _barcodeController = TextEditingController(text: widget.user?.barcode);
    _imageUrlController = TextEditingController(text: widget.user?.imageUrl);
    _imageUrlController.addListener(() {
      if (mounted) setState(() {});
    });

    _selectedRoleId = widget.user?.roleId;
    if (_selectedRoleId == null &&
        widget.roles != null &&
        widget.roles!.isNotEmpty) {
      // Find matching role by name if roleId is null
      if (widget.user != null) {
        final matched = widget.roles!.firstWhere(
          (r) =>
              r['name'].toString().toLowerCase() ==
              widget.user!.role.toLowerCase(),
          orElse: () => null,
        );
        if (matched != null) {
          _selectedRoleId = matched['id'];
        }
      }
    }

    _isActive = widget.user?.isActive ?? true;
    _selectedWarehouseId = widget.user?.warehouseId;

    _selectedRoutingCycle = widget.user?.routingCycle ?? '1_week';
    _routeAssignments = {};
    if (widget.user != null) {
      for (var plan in widget.user!.routePlans) {
        final key = '${plan.weekNumber}_${plan.dayOfWeek}';
        _routeAssignments[key] = plan.routeId;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _commissionRateController.dispose();
    _fixedSalaryController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String _getRoleDisplayName(String name) {
    switch (name.toLowerCase()) {
      case 'owner':
        return 'خاوەن کار (Owner)';
      case 'admin':
        return 'بەڕێوەبەر (Admin)';
      case 'salesman':
        return 'مەندوب (Salesman)';
      case 'warehouse':
        return 'کۆگادار (Warehouse)';
      case 'driver':
        return 'شۆفێر (Driver)';
      default:
        return name;
    }
  }

  Future<void> _save() async {
    final isFormValid = _formKey.currentState!.validate();

    final List<GlobalKey> invalidKeys = [];

    if (_nameController.text.trim().isEmpty) {
      invalidKeys.add(_nameKey);
    }

    if (_phoneController.text.trim().isEmpty) {
      invalidKeys.add(_phoneKey);
    }

    final isEditing = widget.user != null;
    final pass = _passwordController.text;
    if ((!isEditing && pass.isEmpty) || (pass.isNotEmpty && pass.length < 4)) {
      invalidKeys.add(_passwordKey);
    }

    if (_selectedRoleId == null) {
      invalidKeys.add(_roleKey);
    }

    // Find if selected role is salesman or warehouse
    bool isSalesmanSelected = false;
    bool isWarehouseSelected = false;
    final roles = widget.roles ?? [];
    if (_selectedRoleId != null && roles.isNotEmpty) {
      final matched = roles.firstWhere(
        (r) => r['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (matched != null) {
        final rName = matched['name'].toString().toLowerCase();
        if (rName == 'salesman') isSalesmanSelected = true;
        if (rName == 'warehouse') isWarehouseSelected = true;
      }
    }

    final salaryText = _fixedSalaryController.text.trim();
    if (salaryText.isNotEmpty) {
      final parsed = int.tryParse(salaryText);
      if (parsed == null || parsed < 0) {
        invalidKeys.add(_salaryKey);
      }
    }

    if (isSalesmanSelected) {
      final commText = _commissionRateController.text.trim();
      if (commText.isNotEmpty) {
        final parsed = double.tryParse(commText);
        if (parsed == null || parsed < 0 || parsed > 100) {
          invalidKeys.add(_commissionKey);
        }
      }
    }

    if (isWarehouseSelected && _selectedWarehouseId == null) {
      invalidKeys.add(_warehouseKey);
    }

    if (invalidKeys.isNotEmpty || !isFormValid) {
      if (invalidKeys.length == 1) {
        final key = invalidKeys.first;
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      } else {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (_selectedRoleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ تکایە ڕۆڵی بەکارهێنەر دیاری بکە')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _phoneError = null;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;

      // Find if selected role is salesman or warehouse
      bool isSalesmanSelected = false;
      bool isWarehouseSelected = false;
      final roles = widget.roles ?? [];
      if (_selectedRoleId != null && roles.isNotEmpty) {
        final matched = roles.firstWhere(
          (r) => r['id'] == _selectedRoleId,
          orElse: () => null,
        );
        if (matched != null) {
          final rName = matched['name'].toString().toLowerCase();
          if (rName == 'salesman') isSalesmanSelected = true;
          if (rName == 'warehouse') isWarehouseSelected = true;
        }
      }

      final commissionRate = isSalesmanSelected
          ? (double.tryParse(_commissionRateController.text) ?? 0.0)
          : 0.0;
      final fixedSalary =
          int.tryParse(_fixedSalaryController.text.trim()) ?? 0;
      final barcode = _barcodeController.text.trim();
      final imageUrl = _imageUrlController.text.trim();

      final warehouseId = isWarehouseSelected ? _selectedWarehouseId : null;

      final List<Map<String, dynamic>> routePlansPayload = [];
      if (isSalesmanSelected) {
        _routeAssignments.forEach((key, routeId) {
          final parts = key.split('_');
          final week = int.parse(parts[0]);
          final day = parts[1];
          routePlansPayload.add({
            'day_of_week': day,
            'week_number': week,
            'route_id': routeId, // nullable
          });
        });
      }

      if (widget.user == null) {
        // Add
        await ref
            .read(userActionsProvider)
            .addUser(
              name: name,
              phone: phone,
              password: password,
              roleId: _selectedRoleId!,
              commissionRate: commissionRate,
              fixedSalary: fixedSalary,
              barcode: barcode,
              isActive: _isActive,
              warehouseId: warehouseId,
              imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
              routingCycle: isSalesmanSelected ? _selectedRoutingCycle : null,
              routePlans: isSalesmanSelected ? routePlansPayload : null,
            );
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'بەکارهێنەر بە سەرکەوتوویی زیادکرا',
            type: SnackbarType.success,
          );
        }
      } else {
        // Update
        await ref
            .read(userActionsProvider)
            .updateUser(
              widget.user!.id,
              name: name,
              phone: phone,
              password: password.isNotEmpty ? password : null,
              roleId: _selectedRoleId!,
              commissionRate: commissionRate,
              fixedSalary: fixedSalary,
              barcode: barcode,
              isActive: _isActive,
              warehouseId: warehouseId,
              imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
              routingCycle: isSalesmanSelected ? _selectedRoutingCycle : null,
              routePlans: isSalesmanSelected ? routePlansPayload : null,
            );
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'زانیاری بەکارهێنەر بە سەرکەوتوویی نوێکرایەوە',
            type: SnackbarType.success,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final errStr = e.toString();
      final isPhoneError = errStr.contains('پێشتر بەکارهاتووە') ||
          errStr.toLowerCase().contains('phone') ||
          errStr.toLowerCase().contains('taken') ||
          errStr.toLowerCase().contains('unique');

      if (isPhoneError) {
        setState(() {
          _phoneError = 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە';
        });
        _formKey.currentState?.validate();
        if (_phoneKey.currentContext != null) {
          Scrollable.ensureVisible(
            _phoneKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: isPhoneError
              ? 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە، تکایە ژمارەیەکی تر بنووسە'
              : 'هەڵە: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Widget> _buildRoutingScheduleEditor(BuildContext context) {
    final routesAsync = ref.watch(routeListProvider);
    final userAdminAsync = ref.watch(userAdminProvider);
    final theme = Theme.of(context);
    
    return routesAsync.maybeWhen(
      data: (routes) {
        final List<Map<String, String>> days = [
          {'key': 'Saturday', 'label': 'شەممە'},
          {'key': 'Sunday', 'label': 'یەکشەممە'},
          {'key': 'Monday', 'label': 'دووشەممە'},
          {'key': 'Tuesday', 'label': 'سێشەممە'},
          {'key': 'Wednesday', 'label': 'چوارشەممە'},
          {'key': 'Thursday', 'label': 'پێنجشەممە'},
          {'key': 'Friday', 'label': 'هەینی (پشوو - نەگۆڕ)'},
        ];

        // Gather route plans of ALL other salesmen from userAdminAsync
        final List<UserModel> allUsers = userAdminAsync.maybeWhen(
          data: (data) => (data['users'] as List<dynamic>?)?.cast<UserModel>() ?? [],
          orElse: () => <UserModel>[],
        );

        Widget buildDayRow(int weekNum, Map<String, String> day) {
          final isFriday = (day['key'] == 'Friday');
          final assignmentKey = '${weekNum}_${day['key']}';
          final selectedRouteId = _routeAssignments[assignmentKey];

          // Find routes assigned to OTHER salesmen for this specific week and day
          final Set<int> otherAssignedRouteIds = {};
          for (final u in allUsers) {
            if (u.id != widget.user?.id && u.role.toLowerCase() == 'salesman') {
              for (final plan in u.routePlans) {
                if (plan.weekNumber == weekNum && plan.dayOfWeek == day['key']) {
                  otherAssignedRouteIds.add(plan.routeId);
                }
              }
            }
          }

          // Filter out routes that are already assigned to other salesmen
          final filteredRoutes = routes.where((r) => !otherAssignedRouteIds.contains(r.id)).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    day['label']!,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: isFriday ? Colors.grey : theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isFriday
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'پشوو (نەگۆڕ)',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Rudaw'),
                          ),
                        )
                      : DropdownButtonFormField<int>(
                          initialValue: selectedRouteId,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          hint: const Text('پشوو / بێ ڕاوت', style: TextStyle(fontSize: 12, fontFamily: 'Rudaw', color: Colors.grey)),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('پشوو / بێ ڕاوت', style: TextStyle(fontSize: 12, fontFamily: 'Rudaw', color: Colors.grey)),
                            ),
                            ...filteredRoutes.map((r) {
                              return DropdownMenuItem<int>(
                                value: r.id,
                                child: Text(r.name, style: const TextStyle(fontSize: 12, fontFamily: 'Rudaw')),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _routeAssignments[assignmentKey] = val;
                            });
                          },
                        ),
                ),
              ],
            ),
          );
        }

        if (_selectedRoutingCycle == '2_weeks') {
          return [
            const Text('هەفتەی یەکەم (Week 1)', style: AppTextStyles.bodyBold),
            const SizedBox(height: 4),
            ...days.map((day) => buildDayRow(1, day)),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            const Text('هەفتەی دووەم (Week 2)', style: AppTextStyles.bodyBold),
            const SizedBox(height: 4),
            ...days.map((day) => buildDayRow(2, day)),
          ];
        }

        // 1 week
        return [
          ...days.map((day) => buildDayRow(1, day)),
        ];
      },
      orElse: () => [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.user != null;
    final rolesList = widget.roles ?? [];

    // Find if selected role is salesman
    bool isSalesmanSelected = false;
    if (_selectedRoleId != null && rolesList.isNotEmpty) {
      final matched = rolesList.firstWhere(
        (r) => r['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (matched != null &&
          matched['name'].toString().toLowerCase() == 'salesman') {
        isSalesmanSelected = true;
      }
    }

    // Find if selected role is warehouse
    bool isWarehouseSelected = false;
    if (_selectedRoleId != null && rolesList.isNotEmpty) {
      final matched = rolesList.firstWhere(
        (r) => r['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (matched != null &&
          matched['name'].toString().toLowerCase() == 'warehouse') {
        isWarehouseSelected = true;
      }
    }

    final warehousesAsync = ref.watch(warehouseListProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 500,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing
                          ? Icons.edit_outlined
                          : Icons.person_add_alt_1_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'نوێکردنەوەی بەکارهێنەر'
                            : 'تۆمارکردنی بەکارهێنەری نوێ',
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
                const Divider(height: 24),

                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: CustomerAvatar(
                      imageUrl: _imageUrlController.text.trim(),
                      size: 72,
                      borderRadius: 20,
                      placeholderIcon: Icons.person_outline,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                AppTextField(
                  key: _nameKey,
                  controller: _nameController,
                  labelText: 'ناوی تەواو',
                  prefixIcon: Icons.person_outline,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'تکایە ناو بنووسە' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  key: _phoneKey,
                  controller: _phoneController,
                  labelText: 'ژمارەی مۆبایل',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  errorText: _phoneError,
                  onChanged: (val) {
                    if (_phoneError != null) {
                      setState(() {
                        _phoneError = null;
                      });
                    }
                  },
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'تکایە ژمارەی مۆبایل بنووسە';
                    }
                    if (_phoneError != null) {
                      return _phoneError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  key: _passwordKey,
                  controller: _passwordController,
                  labelText: isEditing
                      ? 'وشەی تێپەڕی نوێ (ئەگەر دەتەوێت بیگۆڕیت)'
                      : 'وشەی تێپەڕ (لانی کەم ٤ پیت)',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (val) {
                    if (!isEditing && (val == null || val.isEmpty)) {
                      return 'تکایە وشەی تێپەڕ بنووسە';
                    }
                    if (val != null && val.isNotEmpty && val.length < 4) {
                      return 'پێویستە لانی کەم ٤ پیت بێت';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<int>(
                  key: _roleKey,
                  initialValue: _selectedRoleId,
                  decoration: InputDecoration(
                    labelText: 'ڕۆڵی بەکارهێنەر',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: rolesList.map((r) {
                    return DropdownMenuItem<int>(
                      value: r['id'],
                      child: Text(
                        _getRoleDisplayName(r['name']),
                        style: const TextStyle(fontFamily: 'Rudaw'),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedRoleId = val;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                if (isSalesmanSelected) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          key: _salaryKey,
                          controller: _fixedSalaryController,
                          labelText: 'مووچەی سابتی مانگانە (د.ع)',
                          prefixIcon: Icons.attach_money_outlined,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return null;
                            }
                            final parsed = int.tryParse(val.trim());
                            if (parsed == null || parsed < 0) {
                              return 'ژمارەی دروست بنووسە';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          key: _commissionKey,
                          controller: _commissionRateController,
                          labelText: 'ڕێژەی کۆمسیۆن (%)',
                          prefixIcon: Icons.percent_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return null; // Empty is allowed, defaults to 0.0
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0 || parsed > 100) {
                              return 'لەنێوان 0 بۆ 100 بێت';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else ...[
                  AppTextField(
                    key: _salaryKey,
                    controller: _fixedSalaryController,
                    labelText: 'مووچەی سابتی مانگانە (د.ع)',
                    prefixIcon: Icons.attach_money_outlined,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return null;
                      }
                      final parsed = int.tryParse(val.trim());
                      if (parsed == null || parsed < 0) {
                        return 'ژمارەی دروست بنووسە';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (isWarehouseSelected) ...[
                  warehousesAsync.when(
                    data: (warehouses) {
                      return DropdownButtonFormField<int>(
                        key: _warehouseKey,
                        initialValue: _selectedWarehouseId,
                        decoration: InputDecoration(
                          labelText: 'کۆگای دیاریکراو',
                          prefixIcon: const Icon(Icons.warehouse_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: warehouses.map((w) {
                          return DropdownMenuItem<int>(
                            value: w.id,
                            child: Text(
                              w.name,
                              style: const TextStyle(fontFamily: 'Rudaw'),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedWarehouseId = val;
                          });
                        },
                        validator: (val) =>
                            val == null ? 'تکایە کۆگایەک دیاری بکە' : null,
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'کێشە لە بارکردنی کۆگاکان: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                 AppTextField(
                  controller: _barcodeController,
                  labelText: 'بارکۆدی ناسنامە (ئارەزوومەندانە)',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.autorenew),
                        color: theme.colorScheme.primary,
                        tooltip: 'دروستکردنی کۆدی هەڕەمەکی',
                        onPressed: () {
                          setState(() {
                            _barcodeController.text = _generateRandomString(12);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_2),
                        color: theme.colorScheme.primary,
                        tooltip: 'پیشاندانی QR Code',
                        onPressed: () {
                          final text = _barcodeController.text.trim();
                          if (text.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (_) => _LoginQrCodeDialog(text: text),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تکایە سەرەتا کۆدێک بنووسە یان دروست بکە',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        color: theme.colorScheme.primary,
                        tooltip: 'سکانی QR Code',
                        onPressed: () {
                          CameraBarcodeScanner.show(context, (barcode) {
                            if (mounted) {
                              setState(() {
                                _barcodeController.text = barcode;
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _imageUrlController,
                  labelText: 'بەستەری وێنەی بەکارهێنەر (ئارەزوومەندانە)',
                  hintText: 'https://example.com/avatar.jpg',
                  prefixIcon: Icons.image_outlined,
                ),
                const SizedBox(height: AppSpacing.md),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'باری بەکارهێنەر (چالاک بێت؟)',
                    style: TextStyle(fontFamily: 'Rudaw'),
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  activeThumbColor: theme.colorScheme.primary,
                  activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),

                if (isSalesmanSelected) ...[
                  const Divider(height: 32),
                  const Text('ڕێکخستنی پلانی ڕێڕەو (ڕاوتەکان)', style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.sm),
                  
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoutingCycle,
                    decoration: InputDecoration(
                      labelText: 'خولی دیاریکردنی ڕاوت',
                      prefixIcon: const Icon(Icons.loop_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '1_week',
                        child: Text('یەک هەفتەیی (1-Week)', style: TextStyle(fontFamily: 'Rudaw')),
                      ),
                      DropdownMenuItem(
                        value: '2_weeks',
                        child: Text('دوو هەفتەیی (2-Weeks)', style: TextStyle(fontFamily: 'Rudaw')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRoutingCycle = val);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  ..._buildRoutingScheduleEditor(context),
                ],
                const SizedBox(height: AppSpacing.lg),

                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: isEditing ? 'پاشەکەوتکردن' : 'تۆمارکردن',
                    isLoading: _isLoading,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginQrCodeDialog extends StatefulWidget {
  final String text;

  const _LoginQrCodeDialog({super.key, required this.text});

  @override
  State<_LoginQrCodeDialog> createState() => _LoginQrCodeDialogState();
}

class _LoginQrCodeDialogState extends State<_LoginQrCodeDialog> {
  Uint8List? _qrBytes;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _preGenerateQr();
  }

  Future<void> _preGenerateQr() async {
    final bytes = await _generateQrBytes();
    if (mounted) {
      setState(() {
        _qrBytes = bytes;
        _isGenerating = false;
      });
    }
  }

  Future<Uint8List?> _generateQrBytes() async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: widget.text,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode;
        final painter = QrPainter.withQr(
          qr: qrCode!,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF0F172A),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF0F172A),
          ),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );
        final imageData = await painter.toImageData(512.0);
        return imageData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error generating QR: $e');
    }
    return null;
  }

  Future<void> _handleDownload() async {
    if (_isGenerating && _qrBytes == null) return;
    setState(() => _isGenerating = true);
    final bytes = _qrBytes ?? await _generateQrBytes();
    if (mounted) setState(() => _isGenerating = false);

    if (bytes != null) {
      _qrBytes = bytes;
      downloadBarcode(bytes, 'gardi_qr_${widget.text}.png');
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'وێنەی کۆدەکە (QR) بە سەرکەوتوویی دابەزی',
          type: SnackbarType.success,
        );
      }
    } else if (mounted) {
      AppSnackbar.show(
        context,
        message: 'کێشەیەک لە دروستکردنی وێنەکە ڕوویدا',
        type: SnackbarType.error,
      );
    }
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: 'کۆدەکە کۆپیکرا بۆ Clipboard',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'کۆدی چوونەژوورەوە',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white70 : Colors.black54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.text,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontFamily: 'Rudaw',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _handleCopy,
                    color: theme.colorScheme.primary,
                    tooltip: 'کۆپیکردنی کۆدەکە',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'دابەزاندن',
                icon: Icons.download_outlined,
                onPressed: _isGenerating ? null : _handleDownload,
                isLoading: _isGenerating,
                type: AppButtonType.primary,
                size: AppButtonSize.md,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
