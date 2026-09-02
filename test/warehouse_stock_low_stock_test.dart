import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/warehouse/models/warehouse_stock_model.dart';

void main() {
  group('WarehouseStockModel Low Stock Logic', () {
    test('quantity below minStockLevel should be considered low stock', () {
      final stock = WarehouseStockModel(
        id: 1,
        warehouseId: 1,
        warehouseName: 'Main Warehouse',
        productId: 1,
        productName: 'Test Product',
        barcode: '12345',
        quantity: 5,
        reservedQuantity: 0,
        minStockLevel: 10,
      );

      final isLow = stock.quantity <= stock.minStockLevel;
      expect(isLow, isTrue);
    });

    test('quantity equal to minStockLevel should be considered low stock', () {
      final stock = WarehouseStockModel(
        id: 1,
        warehouseId: 1,
        warehouseName: 'Main Warehouse',
        productId: 1,
        productName: 'Test Product',
        barcode: '12345',
        quantity: 10,
        reservedQuantity: 0,
        minStockLevel: 10,
      );

      final isLow = stock.quantity <= stock.minStockLevel;
      expect(isLow, isTrue);
    });

    test('quantity above minStockLevel should NOT be considered low stock', () {
      final stock = WarehouseStockModel(
        id: 1,
        warehouseId: 1,
        warehouseName: 'Main Warehouse',
        productId: 1,
        productName: 'Test Product',
        barcode: '12345',
        quantity: 15,
        reservedQuantity: 0,
        minStockLevel: 10,
      );

      final isLow = stock.quantity <= stock.minStockLevel;
      expect(isLow, isFalse);
    });

    test('different products can have different thresholds', () {
      final stockA = WarehouseStockModel(
        id: 1,
        warehouseId: 1,
        warehouseName: 'Main',
        productId: 1,
        productName: 'A',
        barcode: 'A',
        quantity: 15,
        reservedQuantity: 0,
        minStockLevel: 10,
      );
      
      final stockB = WarehouseStockModel(
        id: 2,
        warehouseId: 1,
        warehouseName: 'Main',
        productId: 2,
        productName: 'B',
        barcode: 'B',
        quantity: 15,
        reservedQuantity: 0,
        minStockLevel: 20,
      );

      expect(stockA.quantity <= stockA.minStockLevel, isFalse);
      expect(stockB.quantity <= stockB.minStockLevel, isTrue);
    });

    test('parsing min_stock_level from JSON', () {
      final json = {
        'id': 1,
        'warehouse_id': 1,
        'product_id': 1,
        'quantity': 50,
        'reserved_quantity': 5,
        'min_stock_level': 25,
        'product': {'name': 'Product Name', 'barcode': 'B1'},
        'warehouse': {'name': 'Warehouse Name'}
      };

      final model = WarehouseStockModel.fromJson(json);
      expect(model.minStockLevel, 25);
      expect(model.quantity <= model.minStockLevel, isFalse);
    });

    test('missing min_stock_level in JSON should default to 0', () {
      final json = {
        'id': 1,
        'warehouse_id': 1,
        'product_id': 1,
        'quantity': 0,
        'reserved_quantity': 0,
        // min_stock_level is missing
        'product': {'name': 'Product Name', 'barcode': 'B1'},
        'warehouse': {'name': 'Warehouse Name'}
      };

      final model = WarehouseStockModel.fromJson(json);
      expect(model.minStockLevel, 0);
      // quantity 0 <= minStockLevel 0 => isLow should be true (out of stock/at threshold)
      expect(model.quantity <= model.minStockLevel, isTrue);
    });
    
    test('quantity 1 with minStockLevel 0 should NOT be low stock', () {
      final stock = WarehouseStockModel(
        id: 1,
        warehouseId: 1,
        warehouseName: 'W',
        productId: 1,
        productName: 'P',
        barcode: 'B',
        quantity: 1,
        reservedQuantity: 0,
        minStockLevel: 0,
      );
      
      expect(stock.quantity <= stock.minStockLevel, isFalse);
    });
  });
}
