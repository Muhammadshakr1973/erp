import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/responsive_shell.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customer_cart_provider.dart';
import 'customer_catalog_screen.dart';
import 'customer_invoice_screen.dart';

class CustomerMainScreen extends ConsumerStatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  ConsumerState<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends ConsumerState<CustomerMainScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(customerPortalTabIndexProvider.notifier).state = 0;
      ref.read(authProvider.notifier).refreshCurrentUserSilently();
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('چوونەدەرەوە', style: AppTextStyles.h3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'داخستن',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'دڵنیایت لە چوونەدەرەوە لە هەژمارەکەت؟',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'چوونەدەرەوە',
                    style: TextStyle(
                      fontFamily: 'KJino',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(customerPortalTabIndexProvider);
    final itemCount = ref.watch(
      customerCartProvider.select((s) => s.distinctItemCount),
    );

    final screens = [
      CustomerCatalogScreen(onLogout: _confirmLogout),
      CustomerInvoiceScreen(onLogout: _confirmLogout),
    ];

    return ResponsiveShell(
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(customerPortalTabIndexProvider.notifier).state = index;
      },
      body: IndexedStack(
        index: currentIndex,
        children: List.generate(screens.length, (index) {
          final isSelected = index == currentIndex;
          return Visibility(
            visible: isSelected,
            maintainState: true,
            child: FocusScope(
              canRequestFocus: isSelected,
              child: TickerMode(enabled: isSelected, child: screens[index]),
            ),
          );
        }),
      ),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'فرۆشتن بە وێنە',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: itemCount > 0,
            label: Text('$itemCount'),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: itemCount > 0,
            label: Text('$itemCount'),
            child: const Icon(Icons.receipt_long),
          ),
          label: 'پسوڵە',
        ),
      ],
    );
  }
}
