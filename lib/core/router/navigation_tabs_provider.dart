import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation Tab Index Providers for each user role in the application.
/// Tab index 0 always represents the 'سەرەکی' (Dashboard/Main) screen across all roles.

final adminTabIndexProvider = StateProvider<int>((ref) => 0);
final salesmanTabIndexProvider = StateProvider<int>((ref) => 0);
final warehouseTabIndexProvider = StateProvider<int>((ref) => 0);
final driverTabIndexProvider = StateProvider<int>((ref) => 0);

/// Resets all navigation tab providers to 0 ('سەرەکی') using WidgetRef.
void resetAllNavigationTabs(WidgetRef ref) {
  ref.read(adminTabIndexProvider.notifier).state = 0;
  ref.read(salesmanTabIndexProvider.notifier).state = 0;
  ref.read(warehouseTabIndexProvider.notifier).state = 0;
  ref.read(driverTabIndexProvider.notifier).state = 0;
}

/// Resets all navigation tab providers to 0 ('سەرەکی') using Ref.
void resetAllNavigationTabsWithRef(Ref ref) {
  ref.read(adminTabIndexProvider.notifier).state = 0;
  ref.read(salesmanTabIndexProvider.notifier).state = 0;
  ref.read(warehouseTabIndexProvider.notifier).state = 0;
  ref.read(driverTabIndexProvider.notifier).state = 0;
}
