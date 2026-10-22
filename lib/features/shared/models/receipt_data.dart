import '../../admin/models/purchase_order_model.dart';
import '../../auth/models/user_model.dart';
import '../../driver/models/delivery_trip_model.dart';
import '../../admin/models/driver_collection_model.dart';
import '../../orders/models/order_model.dart';
import '../../products/models/supplier_ledger_model.dart';
import 'customer.dart';
import 'customer_ledger_model.dart';
import 'payment_history_model.dart';

class ReceiptData {
  final String title;
  final String receiptNumber;
  final String? date;
  final String? partyLabel;
  final String? partyName;
  final String? partyPhone;
  final String? marketName;
  final String? paymentMethod;
  final String salesmanLabel;
  final String? salesmanName;
  final String? salesmanPhone;
  final String? employeeName;
  final String? employeePhone;
  final List<ReceiptItem> items;
  final List<ReceiptAmount> amounts;
  final String? note;

  const ReceiptData({
    required this.title,
    required this.receiptNumber,
    this.date,
    this.partyLabel,
    this.partyName,
    this.partyPhone,
    this.marketName,
    this.paymentMethod,
    this.salesmanLabel = 'فرۆشیار',
    this.salesmanName,
    this.salesmanPhone,
    this.employeeName,
    this.employeePhone,
    this.items = const [],
    this.amounts = const [],
    this.note,
  });

  factory ReceiptData.fromOrder(
    OrderModel order, {
    UserModel? employee,
  }) {
    final customer = _asMap(order.customer);
    final salesman = _asMap(order.salesman);
    final isCashVanReceipt = employee?.isCashVanSalesman ?? false;
    final marketName = _optionalText(customer['name']);
    final customerName = _optionalText(
      customer['customer_name'] ?? customer['phone2'],
    );

    return ReceiptData(
      title: '',
      receiptNumber: order.orderNumber.isNotEmpty
          ? order.orderNumber
          : order.id.toString(),
      date: order.createdAt,
      partyLabel: 'بەڕێز',
      partyName:
          customerName ?? (marketName == null ? order.customerName : null),
      partyPhone: _optionalText(customer['phone']),
      marketName: marketName,
      salesmanLabel: isCashVanReceipt ? 'کاشڤان' : 'فرۆشیار',
      salesmanName: isCashVanReceipt
          ? _optionalText(employee?.name)
          : _optionalText(salesman['name']) ?? order.salesmanName,
      salesmanPhone: isCashVanReceipt
          ? _optionalText(employee?.phone)
          : _optionalText(salesman['phone']),
      items: order.items
          .map(
            (item) => ReceiptItem(
              name: item.productName,
              quantity: item.quantity,
              unit: item.productUnit,
              unitPrice: item.unitPrice,
              total: item.subtotal,
            ),
          )
          .toList(growable: false),
      amounts: [
        ReceiptAmount('کۆی کاڵاکان', order.subtotal),
        if (order.permanentDiscountAmount > 0)
          ReceiptAmount('داشکاندنی هەمیشەیی', -order.permanentDiscountAmount),
        if (order.discountAmount > 0)
          ReceiptAmount('داشکاندنی پسوڵە', -order.discountAmount),
        ReceiptAmount('کۆی گشتی', order.totalAmount, emphasized: true),
      ],
      note: _optionalText(order.notes),
    );
  }

  factory ReceiptData.fromPurchaseOrder(
    PurchaseOrderModel order, {
    UserModel? employee,
  }) {
    return ReceiptData(
      title: 'پسوڵەی کڕین',
      receiptNumber: order.orderNumber.isNotEmpty
          ? order.orderNumber
          : order.id.toString(),
      date: order.receivedAt?.toIso8601String() ?? order.createdAt,
      partyLabel: 'دابینکەر',
      partyName: order.supplierName,
      partyPhone: order.supplierPhone,
      employeeName: employee?.name,
      employeePhone: employee?.phone,
      items: order.items
          .map(
            (item) => ReceiptItem(
              name: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitCost,
              total: item.totalCost,
            ),
          )
          .toList(growable: false),
      amounts: [
        ReceiptAmount('کۆی گشتی', order.totalAmount, emphasized: true),
      ],
      note: _optionalText(order.notes),
    );
  }

  factory ReceiptData.fromDeliveryOrder(
    DeliveryTripOrderModel tripOrder, {
    UserModel? employee,
  }) {
    final order = tripOrder.order;
    if (order == null) {
      throw StateError('زانیاری پسوڵەی گەیاندن بەردەست نییە.');
    }
    final receipt = ReceiptData.fromOrder(order, employee: employee);
    return ReceiptData(
      title: 'پسوڵەی فرۆشتن و پارەی وەرگیراو',
      receiptNumber: receipt.receiptNumber,
      date: order.createdAt,
      partyLabel: receipt.partyLabel,
      partyName: receipt.partyName,
      partyPhone: receipt.partyPhone,
      salesmanLabel: receipt.salesmanLabel,
      salesmanName: receipt.salesmanName,
      salesmanPhone: receipt.salesmanPhone,
      items: receipt.items,
      amounts: [
        ReceiptAmount('کۆی پسوڵە', order.totalAmount),
        ReceiptAmount('پارەی وەرگیراو', tripOrder.receivedAmount, emphasized: true),
      ],
      note: _optionalText(tripOrder.notes) ?? receipt.note,
    );
  }

  factory ReceiptData.fromSalesReturn(
    Map<String, dynamic> data, {
    required String fallbackNumber,
    UserModel? employee,
  }) {
    final customer = _asMap(data['customer']);
    final items = data['items'] is List
        ? (data['items'] as List)
              .whereType<Map>()
              .map((rawItem) {
                final item = Map<String, dynamic>.from(rawItem);
                final product = _asMap(item['product']);
                return ReceiptItem(
                  name: _optionalText(product['name']) ??
                      _optionalText(item['product_name']) ??
                      'کاڵا',
                  quantity: _number(item['quantity']),
                  unit: _optionalText(product['unit']) ??
                      _optionalText(item['product_unit']),
                  unitPrice: _number(item['unit_price'] ?? item['price']),
                  total: _number(
                    item['total'] ??
                        item['subtotal'] ??
                        item['total_price'] ??
                        item['line_total'],
                  ),
                );
              })
              .toList(growable: false)
        : const <ReceiptItem>[];
    final total = _nullableNumber(
      data['total_return_amount'] ?? data['total_amount'],
    );

    return ReceiptData(
      title: 'پسوڵەی گەڕاندنەوە',
      receiptNumber:
          _optionalText(data['return_number']) ?? fallbackNumber,
      date: _optionalText(data['created_at']),
      partyLabel: 'کڕیار',
      partyName: _optionalText(customer['name']) ?? 'نەناسراو',
      partyPhone: _optionalText(customer['phone']),
      employeeName: employee?.name,
      employeePhone: employee?.phone,
      items: items,
      amounts: total == null
          ? const []
          : [ReceiptAmount('کۆی گشتیی گەڕاندنەوە', total, emphasized: true)],
      note: _optionalText(data['reason']),
    );
  }

  factory ReceiptData.fromPayment(
    PaymentHistoryModel payment, {
    UserModel? employee,
  }) {
    final isCustomerPayment = payment.type.toLowerCase() == 'customer';
    final paymentMethod = switch (payment.paymentMethod.toUpperCase()) {
      'CASH' => 'نەختینە (کاش)',
      'BANK' => 'بانک',
      'TRANSFER' => 'حەواڵە',
      _ => _optionalText(payment.paymentMethod),
    };
    return ReceiptData(
      title: isCustomerPayment ? 'پسوڵەی پارەدانی کڕیار' : 'پسوڵەی پارەدانی دابینکەر',
      receiptNumber: payment.reference.isNotEmpty
          ? payment.reference
          : payment.id.toString(),
      date: payment.paidAt,
      partyLabel: isCustomerPayment ? 'کڕیار' : 'دابینکەر',
      partyName: payment.partyName,
      partyPhone: payment.partyPhone,
      paymentMethod: paymentMethod,
      employeeName: employee?.name,
      employeePhone: employee?.phone,
      amounts: [
        ReceiptAmount('بڕی پارە', payment.amount, emphasized: true),
      ],
      note: _optionalText(payment.notes),
    );
  }

  factory ReceiptData.fromCustomerLedger(
    CustomerLedgerModel entry, {
    Customer? customer,
    String? customerName,
    String? customerPhone,
    UserModel? employee,
  }) {
    final isPayment = entry.entryType.toUpperCase() == 'PAYMENT';
    return ReceiptData(
      title: isPayment ? 'پسوڵەی پارەدانی کڕیار' : 'پسوڵەی جوڵەی قەرز',
      receiptNumber: entry.referenceId?.toString() ?? entry.id.toString(),
      date: entry.createdAt,
      partyLabel: 'کڕیار',
      partyName: customer?.name ?? customerName ?? entry.customerName ?? 'نەزانراو',
      partyPhone: customer?.phone ?? customerPhone,
      employeeName: employee?.name,
      employeePhone: employee?.phone,
      amounts: [
        ReceiptAmount(
          isPayment ? 'بڕی پارەدان' : 'بڕی جوڵە',
          entry.amount,
          emphasized: true,
        ),
        ReceiptAmount('باڵانسی قەرز دوای جوڵە', entry.balanceAfter),
      ],
      note: _optionalText(entry.description),
    );
  }

  factory ReceiptData.fromSupplierLedger(
    SupplierLedgerModel entry, {
    required String supplierName,
    String? supplierPhone,
    UserModel? employee,
  }) {
    final isPayment = entry.entryType.toUpperCase() == 'PAYMENT';
    return ReceiptData(
      title: isPayment ? 'پسوڵەی پارەدانی دابینکەر' : 'پسوڵەی جوڵەی دابینکەر',
      receiptNumber: entry.referenceId?.toString() ?? entry.id.toString(),
      date: entry.createdAt,
      partyLabel: 'دابینکەر',
      partyName: supplierName,
      partyPhone: supplierPhone,
      employeeName: employee?.name,
      employeePhone: employee?.phone,
      amounts: [
        ReceiptAmount(
          isPayment ? 'بڕی پارەدان' : 'بڕی جوڵە',
          entry.amount,
          emphasized: true,
        ),
        ReceiptAmount('باڵانسی دابینکەر دوای جوڵە', entry.balanceAfter),
      ],
      note: _optionalText(entry.description),
    );
  }

  factory ReceiptData.fromDriverCollection(
    DriverCollection collection,
  ) {
    return ReceiptData(
      title: 'پسوڵەی پارەی وەرگیراو لە شۆفێر',
      receiptNumber: collection.id.toString(),
      date: collection.collectedAt,
      partyLabel: 'شۆفێر',
      partyName: collection.driverName,
      partyPhone: collection.driverPhone,
      employeeName: collection.collectorName,
      amounts: [
        ReceiptAmount('بڕی پارەی وەرگیراو', collection.amount, emphasized: true),
      ],
      note: _optionalText(collection.notes),
    );
  }
}

class ReceiptItem {
  final String name;
  final num quantity;
  final String? unit;
  final num unitPrice;
  final num total;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    this.unit,
    required this.unitPrice,
    required this.total,
  });
}

class ReceiptAmount {
  final String label;
  final num amount;
  final bool emphasized;

  const ReceiptAmount(
    this.label,
    this.amount, {
    this.emphasized = false,
  });
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

num _number(dynamic value) => _nullableNumber(value) ?? 0;

num? _nullableNumber(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}
