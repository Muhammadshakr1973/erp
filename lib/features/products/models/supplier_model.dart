class SupplierModel {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final int debt;

  SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.debt = 0,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      address: json['address'],
      contactPerson: json['contact_person'],
      debt: json['debt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
      'debt': debt,
    };
  }
}
