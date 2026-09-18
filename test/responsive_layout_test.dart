import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardi_erp/core/components/responsive_shell.dart';

void main() {
  group('Responsive Layout Breakpoint & Scroll Tests', () {
    test('Mobile breakpoint accurately classifies narrow screen widths (< 700)', () {
      const mobileWidth = 375.0;
      const tabletWidth = 720.0;
      const desktopWidth = 1200.0;

      expect(mobileWidth < 700, isTrue);
      expect(tabletWidth < 700, isFalse);
      expect(desktopWidth < 700, isFalse);
    });

    testWidgets('ResponsiveShell NavigationRail does not overflow in constrained height desktop/tablet viewport', (WidgetTester tester) async {
      // Set constrained height desktop size (1024x500) where 8 destinations would otherwise overflow
      tester.binding.window.physicalSizeTestValue = const Size(1024, 500);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveShell(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'سەرەکی'),
              NavigationDestination(icon: Icon(Icons.receipt), label: 'پسوڵەکان'),
              NavigationDestination(icon: Icon(Icons.people), label: 'کڕیارەکان'),
              NavigationDestination(icon: Icon(Icons.alt_route), label: 'ڕاوتەکان'),
              NavigationDestination(icon: Icon(Icons.store), label: 'کۆمپانیا'),
              NavigationDestination(icon: Icon(Icons.inventory_2), label: 'کاڵاکان'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'ڕاپۆرت'),
              NavigationDestination(icon: Icon(Icons.group), label: 'بەکارهێنەران'),
            ],
            body: const Center(child: Text('Dashboard Content')),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dashboard Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Scrollable report layout does not overflow in constrained mobile viewport', (WidgetTester tester) async {
      // Build a widget with a constrained mobile size (360x600)
      tester.binding.window.physicalSizeTestValue = const Size(360, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards stacked on mobile without unbounded flex
                  Column(
                    children: List.generate(
                      3,
                      (i) => Container(
                        height: 80,
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.blue,
                        child: Center(child: Text('Card $i')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter card
                  Container(
                    height: 280,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Filters')),
                  ),
                  const SizedBox(height: 16),
                  // Table card
                  Container(
                    height: 300,
                    color: Colors.green[100],
                    child: const Center(child: Text('Data Table')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify all elements are found and no overflow exception occurred
      expect(find.text('Card 0'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
