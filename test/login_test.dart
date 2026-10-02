import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/router/navigation_tabs_provider.dart';

void main() {
  group('Login and Navigation Tab Defaults ("سەرەکی")', () {
    test('All role tab index providers default to 0 (سەرەکی)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(adminTabIndexProvider), equals(0),
          reason: 'Admin dashboard tab should default to index 0 (سەرەکی)');
      expect(container.read(salesmanTabIndexProvider), equals(0),
          reason: 'Salesman dashboard tab should default to index 0 (سەرەکی)');
      expect(container.read(warehouseTabIndexProvider), equals(0),
          reason: 'Warehouse dashboard tab should default to index 0 (سەرەکی)');
      expect(container.read(driverTabIndexProvider), equals(0),
          reason: 'Driver dashboard tab should default to index 0 (سەرەکی)');
    });

    test('resetAllNavigationTabsWithRef resets any active tab back to 0 (سەرەکی)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate user navigating to non-zero tabs (e.g. Profile, Orders, Customers)
      container.read(adminTabIndexProvider.notifier).state = 3;
      container.read(salesmanTabIndexProvider.notifier).state = 2;
      container.read(warehouseTabIndexProvider.notifier).state = 1;
      container.read(driverTabIndexProvider.notifier).state = 2;

      expect(container.read(adminTabIndexProvider), equals(3));
      expect(container.read(salesmanTabIndexProvider), equals(2));
      expect(container.read(warehouseTabIndexProvider), equals(1));
      expect(container.read(driverTabIndexProvider), equals(2));

      // Execute tab reset
      resetAllNavigationTabsWithContainer(container);

      // Verify all tabs returned to index 0 (سەرەکی)
      expect(container.read(adminTabIndexProvider), equals(0),
          reason: 'Admin tab must be reset to 0 (سەرەکی) after login/logout');
      expect(container.read(salesmanTabIndexProvider), equals(0),
          reason: 'Salesman tab must be reset to 0 (سەرەکی) after login/logout');
      expect(container.read(warehouseTabIndexProvider), equals(0),
          reason: 'Warehouse tab must be reset to 0 (سەرەکی) after login/logout');
      expect(container.read(driverTabIndexProvider), equals(0),
          reason: 'Driver tab must be reset to 0 (سەرەکی) after login/logout');
    });
  });
}
