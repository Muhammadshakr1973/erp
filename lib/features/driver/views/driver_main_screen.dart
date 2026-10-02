import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/components/responsive_shell.dart';
import '../../../core/router/navigation_tabs_provider.dart';
import 'driver_dashboard_screen.dart';
import 'today_trips_screen.dart';
import '../../shared/views/profile_screen.dart';

export '../../../core/router/navigation_tabs_provider.dart';

class DriverMainScreen extends ConsumerStatefulWidget {
  const DriverMainScreen({super.key});

  @override
  ConsumerState<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends ConsumerState<DriverMainScreen> {
  final List<Widget> _screens = [
    const DriverDashboardScreen(),
    const TodayTripsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(driverTabIndexProvider.notifier).state = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(driverTabIndexProvider);

    return ResponsiveShell(
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(driverTabIndexProvider.notifier).state = index;
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
          icon: Icon(AppIcons.orderDelivered),
          label: 'گەشتەکان',
        ),
        NavigationDestination(icon: Icon(AppIcons.profile), label: 'پڕۆفایل'),
      ],
    );
  }
}
