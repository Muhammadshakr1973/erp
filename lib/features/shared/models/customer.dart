import 'route_model.dart';

class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? customerName;
  final String? address;
  final String? imageUrl;
  final double balance;
  final double creditLimit;
  final int? salesmanId;
  final int? routeId;
  final String? priceType;
  final double permanentDiscount;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final int? visitOrder;
  final RouteModel? route;
  final Map<int, double> specialPrices;

  static Customer get temporary => Customer(
        id: 0,
        name: 'کڕیاری کاتی (بێ ناو)',
        phone: '00000000000',
        address: 'بێ ناونیشان',
        balance: 0.0,
        creditLimit: 0.0,
        priceType: 'N3',
        isActive: true,
        specialPrices: const {},
      );

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.customerName,
    this.address,
    this.imageUrl,
    this.balance = 0.0,
    this.creditLimit = 0.0,
    this.salesmanId,
    this.routeId,
    this.priceType = 'N2',
    this.permanentDiscount = 0.0,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.visitOrder,
    this.route,
    this.specialPrices = const {},
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final Map<int, double> parsedSpecialPrices = {};
    final rawSpecial = json['special_prices'] ?? json['specialPrices'];
    if (rawSpecial is List) {
      for (final sp in rawSpecial) {
        if (sp is Map) {
          final pid = int.tryParse(sp['product_id']?.toString() ?? '');
          final pr = double.tryParse(sp['price']?.toString() ?? '');
          if (pid != null && pr != null) {
            parsedSpecialPrices[pid] = pr;
          }
        }
      }
    }

    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      customerName: json['customer_name'] ?? json['phone2'],
      address: json['address'],
      imageUrl: json['image_url'],
      balance:
          double.tryParse(
            json['current_balance']?.toString() ??
                json['balance']?.toString() ??
                '0',
          ) ??
          0.0,
      creditLimit:
          double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0.0,
      salesmanId: json['salesman_id'],
      routeId: json['route_id'],
      priceType: json['price_type'] ?? 'N2',
      permanentDiscount:
          double.tryParse(json['permanent_discount']?.toString() ?? '0') ??
          0.0,
      isActive:
          json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active'] == null,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      visitOrder: json['visit_order'] != null
          ? int.tryParse(json['visit_order'].toString())
          : null,
      route: json['route'] != null ? RouteModel.fromJson(json['route']) : null,
      specialPrices: parsedSpecialPrices,
    );
  }
}
