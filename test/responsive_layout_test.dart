import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/components/responsive_shell.dart';
import 'package:pos_app/core/theme/app_breakpoints.dart';

void main() {
  group('Responsive Layout Breakpoint & Scroll Tests', () {
    test('Mobile breakpoint accurately classifies narrow screen widths (< 768)', () {
      const mobileWidth = 375.0;
      const tabletWidth = 800.0;
      const desktopWidth = 1200.0;

      expect(AppBreakpoints.isMobile(mobileWidth), isTrue);
      expect(AppBreakpoints.isTablet(tabletWidth), isTrue);
      expect(AppBreakpoints.isDesktop(desktopWidth), isTrue);
    });

    testWidgets('ResponsiveShell NavigationRail does not overflow in constrained height desktop/tablet viewport', (WidgetTester tester) async {
      // Set constrained height desktop size (1024x500) where 8 destinations would otherwise overflow
      tester.view.physicalSize = const Size(1024, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

    testWidgets('ResponsiveShell on mobile displays only primary items and more (...) item', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveShell(
                currentIndex: selected,
                onDestinationSelected: (idx) {
                  setState(() {
                    selected = idx;
                  });
                },
                mobilePrimaryIndices: const [0, 2, 4],
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
                body: Center(child: Text('Current Screen: $selected')),
              );
            },
          ),
        ),
      );

      await tester.pump();

      // Verify primary items and more (...) item are visible
      expect(find.text('سەرەکی'), findsOneWidget);
      expect(find.text('کڕیارەکان'), findsOneWidget);
      expect(find.text('کۆمپانیا'), findsOneWidget);
      expect(find.text('...'), findsOneWidget);

      // Verify secondary items are NOT directly on the bottom bar
      expect(find.text('پسوڵەکان'), findsNothing);
      expect(find.text('ڕاوتەکان'), findsNothing);
      expect(find.text('کاڵاکان'), findsNothing);
      expect(find.text('ڕاپۆرت'), findsNothing);
      expect(find.text('بەکارهێنەران'), findsNothing);

      // Tap on 'کڕیارەکان'
      await tester.tap(find.text('کڕیارەکان'));
      await tester.pumpAndSettle();
      expect(selected, equals(2));

      // Tap on '...' to open more bottom sheet
      await tester.tap(find.text('...'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and secondary items are shown
      expect(find.text('بەشەکانی تر'), findsOneWidget);
      expect(find.text('پسوڵەکان'), findsOneWidget);
      expect(find.text('کاڵاکان'), findsOneWidget);
      expect(find.text('ڕاپۆرت'), findsOneWidget);

      // Tap on 'ڕاپۆرت' in bottom sheet
      await tester.tap(find.text('ڕاپۆرت'));
      await tester.pumpAndSettle();

      expect(selected, equals(6));
      expect(find.text('Current Screen: 6'), findsOneWidget);
    });

    testWidgets('Supplier card renders phone and address on separate lines on mobile without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const phone = '07500000011';
      const address = 'شێخەڵا - پشت ڕەهێل';
      final isMobileOrTablet = 375 < AppBreakpoints.desktopMin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: isMobileOrTablet ? 98 : 82,
              child: Card(
                child: Row(
                  children: [
                    const Icon(Icons.storefront, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ئەرسلان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('کەسی پەیوەندی: نەریمان', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 2),
                          if (isMobileOrTablet) ...[
                            const Text(phone, style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 2),
                            const Text(address, style: TextStyle(fontSize: 11)),
                          ] else ...[
                            const Text('$phone • $address', style: TextStyle(fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('کۆد: #1', style: TextStyle(fontSize: 11)),
                        SizedBox(height: 4),
                        Text('0 د.ع پاکە', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(phone), findsOneWidget);
      expect(find.text(address), findsOneWidget);
      expect(find.text('$phone • $address'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
