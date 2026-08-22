import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import 'salesman_dashboard_screen.dart';
import 'today_customers_screen.dart';
import 'salesman_orders_screen.dart';

class SalesmanMainScreen extends ConsumerStatefulWidget {
  const SalesmanMainScreen({super.key});

  @override
  ConsumerState<SalesmanMainScreen> createState() => _SalesmanMainScreenState();
}

class _SalesmanMainScreenState extends ConsumerState<SalesmanMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SalesmanDashboardScreen(),
    const TodayCustomersScreen(),
    const SalesmanOrdersScreen(),
    const Center(
      child: Text('پڕۆفایل - بەمزووانە', style: AppTextStyles.h2),
    ), // Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(icon: Icon(AppIcons.home), label: 'سەرەکی'),
          NavigationDestination(
            icon: Icon(AppIcons.customers),
            label: 'کڕیارەکان',
          ),
          NavigationDestination(icon: Icon(AppIcons.order), label: 'پسوڵەکان'),
          NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
        ],
      ),
    );
  }
}
