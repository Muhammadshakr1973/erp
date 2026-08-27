class AssignedSalesmanInfo {
  final int id;
  final int salesmanId;
  final String name;
  final String? phone;
  final String? workDate;

  AssignedSalesmanInfo({
    required this.id,
    required this.salesmanId,
    required this.name,
    this.phone,
    this.workDate,
  });

  factory AssignedSalesmanInfo.fromJson(Map<String, dynamic> json) {
    final salesmanMap = json['salesman'] as Map<String, dynamic>?;
    return AssignedSalesmanInfo(
      id: json['id'] ?? 0,
      salesmanId: json['salesman_id'] ?? (salesmanMap?['id'] ?? 0),
      name: salesmanMap?['name'] ?? json['name'] ?? '',
      phone: salesmanMap?['phone'] ?? json['phone'],
      workDate: json['work_date'],
    );
  }
}

class RouteModel {
  final int id;
  final String name;
  final String? color;
  final bool isActive;
  final int customersCount;
  final List<AssignedSalesmanInfo> salesmen;

  RouteModel({
    required this.id,
    required this.name,
    this.color,
    this.isActive = true,
    this.customersCount = 0,
    this.salesmen = const [],
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    var rawSalesmen = json['salesmen'];
    List<AssignedSalesmanInfo> parsedSalesmen = [];
    if (rawSalesmen is List) {
      parsedSalesmen = rawSalesmen
          .map((item) => AssignedSalesmanInfo.fromJson(item))
          .toList();
    }

    return RouteModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      customersCount: json['customers_count'] ?? 0,
      salesmen: parsedSalesmen,
    );
  }
}

