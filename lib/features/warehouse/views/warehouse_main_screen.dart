import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import 'warehouse_dashboard_screen.dart';
import 'orders_to_pack_screen.dart';
import 'stock_list_screen.dart';
import '../../shared/views/profile_screen.dart';

export '../../../core/router/navigation_tabs_provider.dart';

final warehouseLowStockFilterProvider = StateProvider<bool>((ref) => false);

class WarehouseMainScreen extends ConsumerStatefulWidget {
  const WarehouseMainScreen({super.key});

  @override
  ConsumerState<WarehouseMainScreen> createState() =>
      _WarehouseMainScreenState();
}

class _WarehouseMainScreenState extends ConsumerState<WarehouseMainScreen> {
  final List<Widget> _screens = [
    const WarehouseDashboardScreen(),
    const OrdersToPackScreen(),
    const StockListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(warehouseTabIndexProvider.notifier).state = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(warehouseTabIndexProvider);

    return ResponsiveShell(
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(warehouseTabIndexProvider.notifier).state = index;
      },
      body: IndexedStack(
        index: currentIndex,
        children: List.generate(_screens.length, (index) {
          final isSelected = index == currentIndex;
          return Visibility(
            visible: isSelected,
            maintainState: true,
            child: FocusScope(
              canRequestFocus: isSelected,
              child: TickerMode(enabled: isSelected, child: _screens[index]),
            ),
          );
        }),
      ),
      destinations: const [
        NavigationDestination(icon: Icon(AppIcons.home), label: 'سەرەکی'),
        NavigationDestination(
          icon: Icon(AppIcons.orderStatus),
          label: 'پاکەتکردن',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'ستۆک',
        ),
        NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
      ],
    );
  }
}
