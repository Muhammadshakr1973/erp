class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final double balance;
  final double creditLimit;
  final int? salesmanId;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.balance = 0.0,
    this.creditLimit = 0.0,
    this.salesmanId,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      address: json['address'],
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0.0,
      salesmanId: json['salesman_id'],
    );
  }
}
