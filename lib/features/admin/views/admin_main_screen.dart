import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_purchases_screen.dart';
import 'admin_products_screen.dart';
import 'admin_reports_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({super.key});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminOrdersScreen(),
    const AdminCustomersScreen(),
    const AdminPurchasesScreen(),
    const AdminProductsScreen(),
    const AdminReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      currentIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
          icon: Icon(Icons.store), 
          label: 'کۆمپانیا',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined), 
          label: 'کاڵاکان',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart), 
          label: 'ڕاپۆرت',
        ),
      ],
    );
  }
}
