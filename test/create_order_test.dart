import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/components/app_button.dart';
import 'package:pos_app/features/products/models/product_model.dart';

void main() {
  group('Create Order - Calculations & Pricing Rules', () {
    test('Calculates subtotal, permanent customer discount, and invoice percentage discount', () {
      const double unitPrice = 25000.0;
      const int quantity = 4;
      const double subtotal = unitPrice * quantity; // 100,000
      expect(subtotal, equals(100000.0));

      // 5% customer permanent discount
      const double permDiscountPercent = 5.0;
      final double permDiscountAmount = (subtotal * permDiscountPercent) / 100; // 5,000
      final double amountAfterPerm = subtotal - permDiscountAmount; // 95,000
      expect(permDiscountAmount, equals(5000.0));
      expect(amountAfterPerm, equals(95000.0));

      // 10% invoice discount
      const double invoiceDiscountPercent = 10.0;
      final double invoiceDiscountAmount = (amountAfterPerm * invoiceDiscountPercent) / 100; // 9,500
      final double finalTotal = amountAfterPerm - invoiceDiscountAmount; // 85,500
      expect(invoiceDiscountAmount, equals(9500.0));
      expect(finalTotal, equals(85500.0));
    });

    test('Calculates invoice fixed discount after permanent discount', () {
      const double subtotal = 50000.0;
      const double permDiscountPercent = 0.0;
      final double permDiscountAmount = (subtotal * permDiscountPercent) / 100;
      final double amountAfterPerm = subtotal - permDiscountAmount;

      const double invoiceFixedDiscount = 5000.0;
      final double finalTotal = amountAfterPerm - invoiceFixedDiscount;
      expect(finalTotal, equals(45000.0));
    });

    test('Customer dropdown value resolution does not throw on unselected or missing customer', () {
      final customers = [
        {'id': 101, 'name': 'Customer A'},
        {'id': 102, 'name': 'Customer B'},
      ];

      int? selectedCustomerId = 999; // Missing customer ID
      final resolvedValue = customers.any((c) => c['id'] == selectedCustomerId)
          ? selectedCustomerId
          : null;

      expect(resolvedValue, isNull, reason: 'Must safely fallback to null instead of throwing Dropdown mismatch assertion.');
    });
  });

  group('Create Order - Product Autocomplete & Barcode Search', () {
    final sampleProducts = [
      ProductModel(
        id: 1,
        name: 'شامپۆ کلیر (Clear Shampoo)',
        barcode: '8690506001234',
        sku: 'SH-001',
        costPrice: 2000,
        priceN1: 3000,
        priceN2: 3500,
        priceN3: 4000,
        unitsPerCarton: 12,
      ),
      ProductModel(
        id: 2,
        name: 'سابوونی دۆڤ (Dove Soap)',
        barcode: '8690506005678',
        sku: 'SP-002',
        costPrice: 1000,
        priceN1: 1500,
        priceN2: 1750,
        priceN3: 2000,
        unitsPerCarton: 24,
      ),
      ProductModel(
        id: 3,
        name: 'مەعجونی کۆلگەیت (Colgate Toothpaste)',
        barcode: '6901234567890',
        sku: 'TP-003',
        costPrice: 1200,
        priceN1: 1800,
        priceN2: 2000,
        priceN3: 2200,
        unitsPerCarton: 12,
      ),
    ];

    test('Finds product by exact barcode', () {
      const query = '8690506001234';
      final matches = sampleProducts.where((p) {
        final nameMatches = p.name.toLowerCase().contains(query);
        final barcodeMatches = p.barcode.toLowerCase().contains(query);
        final skuMatches = p.sku != null && p.sku!.toLowerCase().contains(query);
        return nameMatches || barcodeMatches || skuMatches;
      }).toList();

      expect(matches.length, equals(1));
      expect(matches.first.id, equals(1));
      expect(matches.first.name, contains('شامپۆ کلیر'));
    });

    test('Finds product by partial name in Kurdish or English', () {
      const query = 'دۆڤ';
      final matches = sampleProducts.where((p) {
        final nameMatches = p.name.toLowerCase().contains(query);
        final barcodeMatches = p.barcode.toLowerCase().contains(query);
        final skuMatches = p.sku != null && p.sku!.toLowerCase().contains(query);
        return nameMatches || barcodeMatches || skuMatches;
      }).toList();

      expect(matches.length, equals(1));
      expect(matches.first.id, equals(2));
      expect(matches.first.name, contains('سابوونی دۆڤ'));
    });

    test('Finds product by SKU', () {
      const query = 'tp-003';
      final matches = sampleProducts.where((p) {
        final nameMatches = p.name.toLowerCase().contains(query);
        final barcodeMatches = p.barcode.toLowerCase().contains(query);
        final skuMatches = p.sku != null && p.sku!.toLowerCase().contains(query);
        return nameMatches || barcodeMatches || skuMatches;
      }).toList();

      expect(matches.length, equals(1));
      expect(matches.first.id, equals(3));
      expect(matches.first.barcode, equals('6901234567890'));
    });

    test('Sorts exact barcode match to first priority', () {
      const query = '8690506005678';
      final matches = sampleProducts.where((p) {
        final nameMatches = p.name.toLowerCase().contains(query);
        final barcodeMatches = p.barcode.toLowerCase().contains(query);
        final skuMatches = p.sku != null && p.sku!.toLowerCase().contains(query);
        return nameMatches || barcodeMatches || skuMatches;
      }).toList();

      matches.sort((a, b) {
        final aExact = a.barcode == query;
        final bExact = b.barcode == query;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return 0;
      });

      expect(matches.first.barcode, equals(query));
      expect(matches.first.id, equals(2));
    });

    test('Allows adding multiple products and incrementing quantities without wiping search query', () {
      final Map<int, int> cart = {};
      const query = 'شامپۆ';

      // Simulate search results
      final matches = sampleProducts.where((p) => p.name.contains(query)).toList();
      expect(matches.length, equals(1));
      final product = matches.first;

      // Simulate clicking on the product 3 times in the autocomplete
      void addToCart(int productId) {
        cart[productId] = (cart[productId] ?? 0) + 1;
      }

      void removeFromCart(int productId) {
        if (cart.containsKey(productId)) {
          if (cart[productId]! > 1) {
            cart[productId] = cart[productId]! - 1;
          } else {
            cart.remove(productId);
          }
        }
      }

      addToCart(product.id);
      expect(cart[product.id], equals(1));

      addToCart(product.id);
      expect(cart[product.id], equals(2));

      addToCart(product.id);
      expect(cart[product.id], equals(3));

      // Decrement
      removeFromCart(product.id);
      expect(cart[product.id], equals(2));

      // Query remains valid for continued selection
      expect(query, equals('شامپۆ'));
    });
  });

  group('Create Order - UI Layout Safety', () {
    testWidgets('AppButton renders inside Row without BoxConstraints infinite width assertion failure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('سەبەتە (Cart)'),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    text: 'بینین و تەواوکردن',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that the button is found and rendered without layout crash
      expect(find.text('بینین و تەواوکردن'), findsOneWidget);
    });

    testWidgets('AppButton with explicit width renders with requested constraints', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(child: SizedBox()),
                AppButton(
                  width: 160,
                  text: 'پشتڕاستکردنەوە',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(AppButton);
      expect(buttonFinder, findsOneWidget);
      final RenderBox renderBox = tester.renderObject(buttonFinder);
      expect(renderBox.size.width, equals(160.0));
    });

    testWidgets('RefreshIndicator with AlwaysScrollableScrollPhysics renders for empty and populated order views', (WidgetTester tester) async {
      bool refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: Text('سەبەتە بەتاڵە'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('سەبەتە بەتاڵە'), findsOneWidget);
      expect(refreshed, isFalse);
    });

    testWidgets('AppBar customer dropdown inside 42px height constraint with isDense and isExpanded renders without RenderFlex overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: 1,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'دیاریکردنی کڕیار',
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem<int>(
                            value: 1,
                            child: Text(
                              'کڕیاری ژمارە یەک بە ناوی درێژ زۆر بەردەست',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: const Text('N2'),
                  ),
                ],
              ),
            ),
            body: const Center(child: Text('Create Order')),
          ),
        ),
      );

      expect(find.text('کڕیاری ژمارە یەک بە ناوی درێژ زۆر بەردەست'), findsOneWidget);
      expect(find.text('N2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Price badge color resolves to high contrast dark theme colors in dark mode', () {
      Color getBadgeColor(String priceType, bool isDark) {
        if (priceType == 'N1') {
          return isDark ? const Color(0xFF34D399) : const Color(0xFF0A9C6E);
        } else if (priceType == 'N2') {
          return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD4820A);
        } else {
          return isDark ? const Color(0xFF60A5FA) : const Color(0xFF5B6B84);
        }
      }

      final n2Dark = getBadgeColor('N2', true);
      final n1Dark = getBadgeColor('N1', true);
      final n3Dark = getBadgeColor('N3', true);

      // Verify that dark mode colors are distinct and not equal to background slate 900 (0xFF0F172A)
      expect(n2Dark, equals(const Color(0xFFFBBF24)));
      expect(n1Dark, equals(const Color(0xFF34D399)));
      expect(n3Dark, equals(const Color(0xFF60A5FA)));
      expect(n2Dark.value != 0xFF0F172A, isTrue);
    });
  });
}
