int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().toLowerCase();

  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

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
      id: _toInt(json['id']),
      salesmanId: _toInt(json['salesman_id'] ?? salesmanMap?['id']),
      name: salesmanMap?['name']?.toString() ?? json['name']?.toString() ?? '',
      phone: salesmanMap?['phone']?.toString() ?? json['phone']?.toString(),
      workDate: json['work_date']?.toString(),
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
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      isActive: _toBool(json['is_active']),
      customersCount: _toInt(json['customers_count']),
      salesmen: parsedSalesmen,
    );
  }
}
