import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/features/warehouse/views/stock_list_screen.dart';
import 'package:pos_app/features/warehouse/providers/warehouse_provider.dart';
import 'package:pos_app/features/warehouse/models/warehouse_stock_model.dart';
import 'package:pos_app/features/auth/providers/auth_provider.dart';
import 'package:pos_app/features/auth/models/user_model.dart';

// Mock AuthNotifier to avoid SharedPreferences dependency and side effects in tests
class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(super.ref, AuthState initialState) {
    state = initialState;
  }
  
  @override
  Future<void> _loadUser() async {
    // Skip real SharedPreferences loading during test
  }
}

void main() {
  final mockStocks = [
    WarehouseStockModel(
      id: 1,
      warehouseId: 10,
      warehouseName: 'کۆگای سەرەکی',
      productId: 101,
      productName: 'شامپۆی برۆکس',
      barcode: '12345678',
      quantity: 15,
      reservedQuantity: 2,
    )
  ];

  group('Warehouse Stock Adjustment Visibility Authorization Tests', () {
    testWidgets('1. Adjustment button is VISIBLE for user with stock.pack permission', (WidgetTester tester) async {
      final userWithPermission = UserModel(
        id: 1,
        name: 'Authorized User',
        phone: '123',
        role: 'warehouse',
        permissions: ['stock.pack', 'stock.view'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseStocksProvider.overrideWith((ref) => mockStocks),
            authProvider.overrideWith((ref) => MockAuthNotifier(ref, AuthState(user: userWithPermission))),
          ],
          child: const MaterialApp(
            home: StockListScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify the adjustment button (tooltip: 'دەستکاریکردنی ستۆک') exists
      expect(find.byTooltip('دەستکاریکردنی ستۆک'), findsOneWidget);
    });

    testWidgets('2. Adjustment button is HIDDEN for user WITHOUT stock.pack permission', (WidgetTester tester) async {
      final userWithoutPermission = UserModel(
        id: 2,
        name: 'Unauthorized User',
        phone: '456',
        role: 'warehouse',
        permissions: ['stock.view'], // Missing stock.pack
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseStocksProvider.overrideWith((ref) => mockStocks),
            authProvider.overrideWith((ref) => MockAuthNotifier(ref, AuthState(user: userWithoutPermission))),
          ],
          child: const MaterialApp(
            home: StockListScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify the adjustment button is NOT present
      expect(find.byTooltip('دەستکاریکردنی ستۆک'), findsNothing);
    });

    testWidgets('3. Warehouse reconciliation button remains visible for users with stock.view', (WidgetTester tester) async {
      // Business Rule: Adjustment is restricted, but reconciliation (report-only) 
      // might still be visible if the user can view stock.
      final user = UserModel(
        id: 3,
        name: 'Viewer User',
        phone: '789',
        role: 'warehouse',
        permissions: ['stock.view'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseStocksProvider.overrideWith((ref) => mockStocks),
            authProvider.overrideWith((ref) => MockAuthNotifier(ref, AuthState(user: user))),
          ],
          child: const MaterialApp(
            home: StockListScreen(),
          ),
        ),
      );

      await tester.pump();

      // Adjustment button should be hidden
      expect(find.byTooltip('دەستکاریکردنی ستۆک'), findsNothing);
      // Reconciliation button should still be visible (tooltip: 'هاوتاکردنەوە')
      expect(find.byTooltip('هاوتاکردنەوە'), findsOneWidget);
    });
  });
}
