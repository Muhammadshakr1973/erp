import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
// ignore: unused_import
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import 'salesman_dashboard_screen.dart';
import 'today_customers_screen.dart';
import 'salesman_orders_screen.dart';
import '../../auth/views/profile_placeholder.dart'; // We will create this

class SalesmanMainScreen extends ConsumerStatefulWidget {
  const SalesmanMainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SalesmanMainScreen> createState() => _SalesmanMainScreenState();
}

class _SalesmanMainScreenState extends ConsumerState<SalesmanMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SalesmanDashboardScreen(),
    const TodayCustomersScreen(),
    const SalesmanOrdersScreen(),
    const Center(child: Text('پڕۆفایل - بەمزووانە', style: AppTextStyles.h2)), // Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            label: 'سەرەکی',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.customers),
            label: 'کڕیارەکان',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.order),
            label: 'پسوڵەکان',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.profile),
            label: 'پڕۆفایل',
          ),
        ],
      ),
    );
  }
}
