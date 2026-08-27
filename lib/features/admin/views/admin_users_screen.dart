import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';


import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/camera_barcode_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
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

  void _showUserFormDialog(BuildContext context, [UserModel? user, List<dynamic>? roles]) {
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
        title: const Text('سڕینەوەی بەکارهێنەر', style: AppTextStyles.h3),
        content: Text('دڵنیایت لە سڕینەوەی بەکارهێنەر "${user.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە', style: TextStyle(fontFamily: 'Rudaw')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await ref.read(userActionsProvider).deleteUser(user.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('بەکارهێنەر بە سەرکەوتوویی سڕایەوە')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('کێشە: $e')),
                  );
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
            error: (_, __) => const SizedBox.shrink(),
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
                    hintText: 'گەڕان بەدوای بەکارهێنەر (ناو، مۆبایل، ئیمەیڵ)...',
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('هەڵەیەک ڕوویدا: $err', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
              data: (data) {
                final List<UserModel> users = data['users'] ?? [];
                final List<dynamic> roles = data['roles'] ?? [];

                final filteredUsers = users.where((u) {
                  final nameMatch = u.name.toLowerCase().contains(_searchQuery);
                  final phoneMatch = u.phone.toLowerCase().contains(_searchQuery);
                  return nameMatch || phoneMatch;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: AppSpacing.sm),
                        Text('هیچ بەکارهێنەرێک نەدۆزرایەوە', style: AppTextStyles.bodyBold),
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
                    mainAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 145,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final roleColor = _getRoleColor(user.role, theme);

                    return AppCard(
                      onTap: () => _showUserFormDialog(context, user, roles),
                      onLongPress: () => _showDeleteUserDialog(context, user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                user.role.toLowerCase() == 'salesman'
                                    ? Icons.badge_outlined
                                    : user.role.toLowerCase() == 'admin' || user.role.toLowerCase() == 'owner'
                                        ? Icons.admin_panel_settings_outlined
                                        : Icons.person_outline,
                                color: roleColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    user.name,
                                    style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'تەلەفۆن: ${user.phone}',
                                    style: AppTextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  if (user.role.toLowerCase() == 'salesman' && user.commissionRate != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'کۆمسیۆن: ${user.commissionRate}%',
                                      style: AppTextStyles.caption.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
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
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (user.isActive ?? true)
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (user.isActive ?? true) ? 'چالاک' : 'ناچالاک',
                                    style: TextStyle(
                                      color: (user.isActive ?? true) ? Colors.green : Colors.red,
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
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _commissionRateController;
  late final TextEditingController _barcodeController;

  int? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name);
    _phoneController = TextEditingController(text: widget.user?.phone);
    _passwordController = TextEditingController();
    _commissionRateController = TextEditingController(
      text: widget.user?.commissionRate != null ? widget.user!.commissionRate!.toString() : '0.0',
    );
    _barcodeController = TextEditingController(text: widget.user?.barcode);

    _selectedRoleId = widget.user?.roleId;
    if (_selectedRoleId == null && widget.roles != null && widget.roles!.isNotEmpty) {
      // Find matching role by name if roleId is null
      if (widget.user != null) {
        final matched = widget.roles!.firstWhere(
          (r) => r['name'].toString().toLowerCase() == widget.user!.role.toLowerCase(),
          orElse: () => null,
        );
        if (matched != null) {
          _selectedRoleId = matched['id'];
        }
      }
    }

    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _commissionRateController.dispose();
    _barcodeController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ تکایە ڕۆڵی بەکارهێنەر دیاری بکە')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;
      final commissionRate = double.tryParse(_commissionRateController.text) ?? 0.0;
      final barcode = _barcodeController.text.trim();

      if (widget.user == null) {
        // Add
        await ref.read(userActionsProvider).addUser(
              name: name,
              phone: phone,
              password: password,
              roleId: _selectedRoleId!,
              commissionRate: commissionRate,
              barcode: barcode,
              isActive: _isActive,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بەکارهێنەر بە سەرکەوتوویی زیادکرا')),
          );
        }
      } else {
        // Update
        await ref.read(userActionsProvider).updateUser(
              widget.user!.id,
              name: name,
              phone: phone,
              password: password.isNotEmpty ? password : null,
              roleId: _selectedRoleId!,
              commissionRate: commissionRate,
              barcode: barcode,
              isActive: _isActive,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('زانیاری بەکارهێنەر بە سەرکەوتوویی نوێکرایەوە')),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    final rolesList = widget.roles ?? [];

    // Find if selected role is salesman
    bool isSalesmanSelected = false;
    if (_selectedRoleId != null && rolesList.isNotEmpty) {
      final matched = rolesList.firstWhere(
        (r) => r['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (matched != null && matched['name'].toString().toLowerCase() == 'salesman') {
        isSalesmanSelected = true;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit_outlined : Icons.person_add_alt_1_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'نوێکردنەوەی بەکارهێنەر' : 'تۆمارکردنی بەکارهێنەری نوێ',
                      style: AppTextStyles.h2,
                    ),
                  ],
                ),
                const Divider(height: 24),

                AppTextField(
                  controller: _nameController,
                  labelText: 'ناوی تەواو',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => val == null || val.isEmpty ? 'تکایە ناو بنووسە' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _phoneController,
                  labelText: 'ژمارەی مۆبایل',
                  prefixIcon: Icons.phone_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'تکایە ژمارەی مۆبایل بنووسە' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _passwordController,
                  labelText: isEditing ? 'وشەی تێپەڕی نوێ (ئەگەر دەتەوێت بیگۆڕیت)' : 'وشەی تێپەڕ (لانی کەم ٦ پیت)',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: AppColors.primary),
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
                    if (val != null && val.isNotEmpty && val.length < 6) {
                      return 'پێویستە لانی کەم ٦ پیت بێت';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<int>(
                  value: _selectedRoleId,
                  decoration: InputDecoration(
                    labelText: 'ڕۆڵی بەکارهێنەر',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: rolesList.map((r) {
                    return DropdownMenuItem<int>(
                      value: r['id'],
                      child: Text(_getRoleDisplayName(r['name']), style: const TextStyle(fontFamily: 'Rudaw')),
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
                  AppTextField(
                    controller: _commissionRateController,
                    labelText: 'ڕێژەی کۆمسیۆن (%)',
                    prefixIcon: Icons.percent_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'تکایە ڕێژەی کۆمسیۆن دیاری بکە';
                      final parsed = double.tryParse(val);
                      if (parsed == null || parsed < 0 || parsed > 100) {
                        return 'ڕێژەیەکی دروست بنووسە لەنێوان 0 بۆ 100';
                      }
                      return null;
                    },
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
                        color: AppColors.primary,
                        tooltip: 'دروستکردنی کۆدی هەڕەمەکی',
                        onPressed: () {
                          setState(() {
                            _barcodeController.text = _generateRandomString(12);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_2),
                        color: AppColors.primary,
                        tooltip: 'پیشاندانی QR Code',
                        onPressed: () {
                          final text = _barcodeController.text.trim();
                          if (text.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('کۆدی چوونەژوورەوە', style: AppTextStyles.h3, textAlign: TextAlign.center),
                                content: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: QrImageView(
                                    data: text,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('داخستن', style: TextStyle(fontFamily: 'Rudaw')),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تکایە سەرەتا کۆدێک بنووسە یان دروست بکە')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        color: AppColors.primary,
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

                SwitchListTile(
                  title: const Text('باری بەکارهێنەر (چالاک بێت؟)', style: TextStyle(fontFamily: 'Rudaw')),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  activeColor: AppColors.primary,
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
                      width: 140,
                      child: AppButton(
                        text: isEditing ? 'پاشکەوتکردن' : 'تۆمارکردن',
                        isLoading: _isLoading,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
