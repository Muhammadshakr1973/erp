import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/components/responsive_shell.dart';
import 'salesman_dashboard_screen.dart';
import 'today_customers_screen.dart';
import 'salesman_orders_screen.dart';
import '../../shared/views/profile_screen.dart';

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
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_screens.length, (index) {
          final isSelected = index == _currentIndex;
          return Visibility(
            visible: isSelected,
            maintainState: true,
            child: FocusScope(
              canRequestFocus: isSelected,
              child: TickerMode(
                enabled: isSelected,
                child: _screens[index],
              ),
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
