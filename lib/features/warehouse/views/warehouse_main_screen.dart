import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import 'warehouse_dashboard_screen.dart';
import 'orders_to_pack_screen.dart';
import 'stock_list_screen.dart';
import '../../shared/views/profile_screen.dart';

class WarehouseMainScreen extends ConsumerStatefulWidget {
  const WarehouseMainScreen({super.key});

  @override
  ConsumerState<WarehouseMainScreen> createState() => _WarehouseMainScreenState();
}

class _WarehouseMainScreenState extends ConsumerState<WarehouseMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WarehouseDashboardScreen(),
    const OrdersToPackScreen(),
    const StockListScreen(),
    const ProfileScreen(),
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
      body: IndexedStack(index: _currentIndex, children: _screens),
      destinations: const [
        NavigationDestination(icon: Icon(AppIcons.home), label: 'سەرەکی'),
        NavigationDestination(icon: Icon(AppIcons.orderStatus), label: 'پاکەتکردن'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'ستۆک'),
        NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
      ],
    );
  }
}
