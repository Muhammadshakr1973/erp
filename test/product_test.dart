import 'package:flutter_test/flutter_test.dart';
import 'package:gardi_erp/features/products/models/product_model.dart';

void main() {
  group('ProductModel and Product Card Data Verification', () {
    test('Parses all fields required for 3-column admin product card', () {
      final json = {
        'id': 1,
        'name': 'پەنیر',
        'sku': 'SKU-001',
        'barcode': '123456789',
        'category': {'name': 'شیرەمەنی'},
        'supplier': {'name': 'کۆمپانیای ئاراس'},
        'unit': 'کارتۆن',
        'units_per_carton': 24,
        'cost_price': '1000',
        'price_n1': '1500',
        'price_n2': '1400',
        'price_n3': '1300',
        'image_path': 'https://example.com/cheese.jpg',
        'is_active': 1,
        'stocks': [
          {'warehouse_id': 1, 'quantity': 15},
          {'warehouse_id': 2, 'quantity': 10},
        ],
      };

      final product = ProductModel.fromJson(json);

      // Column 1 verification (Image, Category, Supplier, SKU)
      expect(product.imagePath, 'https://example.com/cheese.jpg');
      expect(product.category?['name'], 'شیرەمەنی');
      expect(product.supplier?['name'], 'کۆمپانیای ئاراس');
      expect(product.sku, 'SKU-001');

      // Column 2 verification (Name, Barcode, Unit packaging)
      expect(product.name, 'پەنیر');
      expect(product.barcode, '123456789');
      expect(product.unit, 'کارتۆن');
      expect(product.unitsPerCarton, 24);

      // Column 3 verification (Cost, N1, N2, N3)
      expect(product.costPrice, 1000.0);
      expect(product.priceN1, 1500.0);
      expect(product.priceN2, 1400.0);
      expect(product.priceN3, 1300.0);

      // Stock badge aggregation verification
      int totalStock = 0;
      for (var stock in product.stocks) {
        totalStock += (stock['quantity'] as int?) ?? 0;
      }
      expect(totalStock, 25);
      expect(totalStock < 20, isFalse); // Not low stock
    });

    test('Correctly identifies low stock threshold for badge styling', () {
      final lowStockProduct = ProductModel.fromJson({
        'id': 2,
        'name': 'کەرە',
        'barcode': '987654321',
        'cost_price': '500',
        'price_n1': '800',
        'price_n2': '750',
        'price_n3': '700',
        'stocks': [
          {'warehouse_id': 1, 'quantity': 5},
        ],
      });

      int totalStock = 0;
      for (var stock in lowStockProduct.stocks) {
        totalStock += (stock['quantity'] as int?) ?? 0;
      }
      expect(totalStock, 5);
      expect(totalStock < 20, isTrue); // Low stock triggers warning badge
    });
  });
}
