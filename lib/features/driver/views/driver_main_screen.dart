import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import 'driver_dashboard_screen.dart';
import 'today_trips_screen.dart';
import '../../shared/views/profile_screen.dart';

class DriverMainScreen extends ConsumerStatefulWidget {
  const DriverMainScreen({super.key});

  @override
  ConsumerState<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends ConsumerState<DriverMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DriverDashboardScreen(),
    const TodayTripsScreen(),
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
        NavigationDestination(icon: Icon(AppIcons.orderDelivered), label: 'گەشتەکان'),
        NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
      ],
    );
  }
}
