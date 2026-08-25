class SupplierModel {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;

  SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      address: json['address'],
      contactPerson: json['contact_person'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
    };
  }
}
