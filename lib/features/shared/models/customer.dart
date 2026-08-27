class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? phone2;
  final String? address;
  final String? imageUrl;
  final double balance;
  final double creditLimit;
  final int? salesmanId;
  final int? routeId;
  final String? priceType;
  final bool isActive;
  final double? latitude;
  final double? longitude;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.phone2,
    this.address,
    this.imageUrl,
    this.balance = 0.0,
    this.creditLimit = 0.0,
    this.salesmanId,
    this.routeId,
    this.priceType = 'N2',
    this.isActive = true,
    this.latitude,
    this.longitude,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      phone2: json['phone2'],
      address: json['address'],
      imageUrl: json['image_url'],
      balance: double.tryParse(json['current_balance']?.toString() ?? json['balance']?.toString() ?? '0') ?? 0.0,
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0.0,
      salesmanId: json['salesman_id'],
      routeId: json['route_id'],
      priceType: json['price_type'] ?? 'N2',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
  }
}
