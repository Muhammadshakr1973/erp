import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/router/navigation_tabs_provider.dart';

void main() {
  group('Role Dashboard and Navigation Flow', () {
    test('Navigation tab index resets to 0 (سەرەکی) for all client views', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial states are 0 ('سەرەکی')
      expect(container.read(adminTabIndexProvider), equals(0));
      expect(container.read(salesmanTabIndexProvider), equals(0));
      expect(container.read(warehouseTabIndexProvider), equals(0));
      expect(container.read(driverTabIndexProvider), equals(0));

      // Alter indexes
      container.read(adminTabIndexProvider.notifier).state = 1;
      container.read(salesmanTabIndexProvider.notifier).state = 3;
      container.read(warehouseTabIndexProvider.notifier).state = 2;
      container.read(driverTabIndexProvider.notifier).state = 1;

      // Reset
      resetAllNavigationTabsWithRef(container);

      // Validate all restored to index 0 ('سەرەکی')
      expect(container.read(adminTabIndexProvider), equals(0));
      expect(container.read(salesmanTabIndexProvider), equals(0));
      expect(container.read(warehouseTabIndexProvider), equals(0));
      expect(container.read(driverTabIndexProvider), equals(0));
    });
  });
}
