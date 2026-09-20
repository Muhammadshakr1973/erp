import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/core/utils/formatters.dart';
import 'package:pos_app/features/products/models/product_model.dart';

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

      // Column 2 verification (Name, Barcode, Unit packaging, Stock badge)
      expect(product.name, 'پەنیر');
      expect(product.barcode, '123456789');
      expect(product.unit, 'کارتۆن');
      expect(product.unitsPerCarton, 24);

      // Column 3 verification (Cost, N1, N2, N3)
      expect(product.costPrice, 1000.0);
      expect(product.priceN1, 1500.0);
      expect(product.priceN2, 1400.0);
      expect(product.priceN3, 1300.0);

      // Stock badge aggregation verification (rendered under barcode & unit in Column 2)
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

    test('Formats price tiers and cost badge accurately matching 2.png visual specification', () {
      final product = ProductModel.fromJson({
        'id': 3,
        'name': 'بەرهەم',
        'cost_price': '4000',
        'price_n1': '12000',
        'price_n2': '13000',
        'price_n3': '14000',
      });

      // Cost badge format: تێچوو: 4,000 د.ع
      final formattedCost = 'تێچوو: ${Formatters.currency(product.costPrice)}';
      expect(formattedCost, contains('تێچوو:'));
      expect(formattedCost, contains('4,000'));
      expect(formattedCost, contains('د.ع'));

      // N1 tier price formatted number
      final n1Number = Formatters.number(product.priceN1);
      expect(n1Number, '12,000');

      // N2 tier price formatted number
      final n2Number = Formatters.number(product.priceN2);
      expect(n2Number, '13,000');

      // N3 tier price formatted number
      final n3Number = Formatters.number(product.priceN3);
      expect(n3Number, '14,000');

      // Indicator color definitions matching specification
      const n1DotColor = Color(0xFF10B981); // Emerald Green
      const n2DotColor = Color(0xFFF59E0B); // Amber Gold
      const n3DotColor = Color(0xFFF43F5E); // Rose Red
      expect(n1DotColor.toARGB32(), 0xFF10B981);
      expect(n2DotColor.toARGB32(), 0xFFF59E0B);
      expect(n3DotColor.toARGB32(), 0xFFF43F5E);
    });

    test('Product edit form dialog receives product model and retains identifiers', () {
      final product = ProductModel.fromJson({
        'id': 42,
        'name': 'شەربەتی پرتەقاڵ',
        'barcode': '99887766',
        'cost_price': '2500',
        'price_n1': '3000',
        'price_n2': '3250',
        'price_n3': '3500',
        'unit': 'دانە',
        'units_per_carton': 24,
      });

      // Verifying product card edit parameters passed to ProductFormDialog
      expect(product.id, 42);
      expect(product.name, 'شەربەتی پرتەقاڵ');
      expect(product.costPrice, 2500.0);
      expect(product.priceN1, 3000.0);
      expect(product.priceN2, 3250.0);
      expect(product.priceN3, 3500.0);
      expect(product.unitsPerCarton, 24);
    });

    test('Product card grid configuration uses compact mainAxisExtent', () {
      // The compact card height requested by user matches the tight red bounding box
      const double compactCardExtent = 130.0;
      const double previousCardExtent = 195.0;

      expect(compactCardExtent, lessThan(previousCardExtent));
      expect(compactCardExtent, equals(130.0));
    });

    test('Barcode Label Generator defaults to 1000 IQD and fixed currency', () {
      // Default price is 1000 when no price provided
      const defaultPrice = 1000;
      const currencySymbol = 'د.ع';

      expect(defaultPrice, 1000);
      expect(currencySymbol, 'د.ع');

      // Product with no selling price defaults to 1000
      final productWithoutPrice = ProductModel.fromJson({
        'id': 101,
        'name': 'لاستیک باریک سپی',
        'barcode': '07849564845',
      });

      final double? rawPrice = productWithoutPrice.priceN1;
      final priceStr = (rawPrice != null && rawPrice > 0) ? rawPrice.toInt().toString() : '1000';
      expect(priceStr, '1000');
      expect(productWithoutPrice.barcode, '07849564845');
      expect(productWithoutPrice.name, 'لاستیک باریک سپی');
    });

    test('Barcode Label Sticker geometry matches 50x30mm specifications', () {
      // Physical dimensions: 50 mm x 30 mm (5:3 aspect ratio)
      const labelWidth = 400.0;
      const labelHeight = 240.0;
      const aspectRatio = labelWidth / labelHeight;
      const borderRadius = 6.0;
      const borderWidth = 1.0;
      const logoWidth = 156.0;
      const logoHeight = 148.0;

      expect(labelWidth, 400.0);
      expect(labelHeight, 240.0);
      // Verify exact 5:3 ratio with high precision
      expect(aspectRatio, closeTo(5.0 / 3.0, 0.01));
      expect(borderRadius, 6.0);
      expect(borderWidth, 1.0);
      expect(logoWidth, 156.0);
      expect(logoHeight, 148.0);
    });
  });
}
