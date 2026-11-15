import 'dart:convert';

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
  final bool canLogin;
  final String? loginCode;
  final List<int> allowedCategoryIds;
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
        canLogin: false,
        allowedCategoryIds: const [],
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
    this.canLogin = false,
    this.loginCode,
    this.allowedCategoryIds = const [],
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

    final List<int> parsedAllowedCategoryIds = [];
    dynamic rawAllowedCategories = json['allowed_category_ids'];
    if (rawAllowedCategories is String && rawAllowedCategories.trim().isNotEmpty) {
      try {
        rawAllowedCategories = jsonDecode(rawAllowedCategories);
      } catch (_) {}
    }
    if (rawAllowedCategories is List) {
      for (final cid in rawAllowedCategories) {
        final parsed = int.tryParse(cid.toString());
        if (parsed != null && !parsedAllowedCategoryIds.contains(parsed)) {
          parsedAllowedCategoryIds.add(parsed);
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
      canLogin: json['can_login'] == 1 || json['can_login'] == true,
      loginCode: json['login_code']?.toString(),
      allowedCategoryIds: parsedAllowedCategoryIds,
      route: json['route'] != null
          ? RouteModel.fromJson(Map<String, dynamic>.from(json['route'] as Map))
          : null,
      specialPrices: parsedSpecialPrices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'customer_name': customerName,
      'address': address,
      'image_url': imageUrl,
      'current_balance': balance,
      'credit_limit': creditLimit,
      'salesman_id': salesmanId,
      'route_id': routeId,
      'price_type': priceType,
      'permanent_discount': permanentDiscount,
      'is_active': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'visit_order': visitOrder,
      'can_login': canLogin,
      'login_code': loginCode,
      'allowed_category_ids': allowedCategoryIds,
      if (route != null) 'route': route!.toJson(),
      'special_prices': specialPrices.entries
          .map((e) => {'product_id': e.key, 'price': e.value})
          .toList(),
    };
  }
}
