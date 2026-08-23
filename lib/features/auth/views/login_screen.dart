import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'تکایە ژمارەی مۆبایل و وشەی نهێنی پڕبکەرەوە',
        type: SnackbarType.warning,
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).login(phone, password);

    if (success && mounted) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        if (user.role == 'admin' || user.role == 'owner') {
          context.go('/admin');
        } else if (user.role == 'salesman') {
          context.go('/salesman');
        } else if (user.role == 'warehouse') {
          context.go('/warehouse');
        } else if (user.role == 'driver') {
          context.go('/driver');
        } else {
          AppSnackbar.show(
            context,
            message: 'ڕۆڵی بەکارهێنەر نەناسراوە',
            type: SnackbarType.error,
          );
        }
      }
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        AppSnackbar.show(
          context,
          message: error,
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.storefront,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'بەخێربێیتەوە',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بۆ چوونەژوورەوە زانیارییەکانت پڕبکەرەوە',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  AppTextField(
                    labelText: 'ژمارەی مۆبایل',
                    hintText: '0750 000 0000',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    labelText: 'وشەی نهێنی',
                    hintText: 'وشەی نهێنی بنووسە',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 48),
                  AppButton(
                    text: 'چوونەژوورەوە',
                    isLoading: authState.isLoading,
                    size: AppButtonSize.lg,
                    onPressed: _handleLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
