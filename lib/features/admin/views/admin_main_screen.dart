import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_icons.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_products_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminOrdersScreen(),
    const AdminCustomersScreen(),
    const AdminProductsScreen(),
    const Center(child: Text('ڕاپۆرتەکان و ڕێکخستن - بەمزووانە')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            icon: Icon(AppIcons.order),
            label: 'پسوڵەکان',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.customers),
            label: 'کڕیارەکان',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined), // Products Icon
            label: 'کاڵاکان',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart), // Reports Icon
            label: 'ڕاپۆرت',
          ),
        ],
      ),
    );
  }
}
