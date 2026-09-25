import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import 'salesman_dashboard_screen.dart';
import 'today_customers_screen.dart';
import 'salesman_orders_screen.dart';
import '../../shared/views/profile_screen.dart';

final salesmanTabIndexProvider = StateProvider<int>((ref) => 0);

class SalesmanMainScreen extends ConsumerStatefulWidget {
  const SalesmanMainScreen({super.key});

  @override
  ConsumerState<SalesmanMainScreen> createState() => _SalesmanMainScreenState();
}

class _SalesmanMainScreenState extends ConsumerState<SalesmanMainScreen> {
  final List<Widget> _screens = [
    const SalesmanDashboardScreen(),
    const TodayCustomersScreen(),
    const SalesmanOrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(salesmanTabIndexProvider);

    return ResponsiveShell(
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(salesmanTabIndexProvider.notifier).state = index;
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
          icon: Icon(AppIcons.customers),
          label: 'کڕیارەکان',
        ),
        NavigationDestination(icon: Icon(AppIcons.order), label: 'پسوڵەکان'),
        NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
      ],
    );
  }
}
