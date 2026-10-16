import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class WarehouseModel {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool isMain;
  final bool isActive;
  final String type;
  final int stocksCount;

  WarehouseModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isMain = false,
    this.isActive = true,
    this.type = 'PHYSICAL',
    this.stocksCount = 0,
  });

  bool get isVan => type.toUpperCase() == 'VAN' || name.contains('کاشڤان');

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      isMain: json['is_main'] == true || json['is_main'] == 1,
      isActive: json['is_active'] != false && json['is_active'] != 0,
      type: json['type']?.toString().toUpperCase() ?? 'PHYSICAL',
      stocksCount: (json['stocks_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'is_main': isMain,
      'is_active': isActive,
      'type': type,
    };
  }
}

final warehouseListProvider = FutureProvider<List<WarehouseModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/warehouses');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw const FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed warehouse response payload)',
        );
      }
      final List data = resData['data'] as List;
      return data.map((json) => WarehouseModel.fromJson(json)).toList();
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final warehouseAdminActionsProvider = Provider<WarehouseAdminActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return WarehouseAdminActions(api, ref);
});

class WarehouseAdminActions {
  final ApiClient api;
  final Ref ref;

  WarehouseAdminActions(this.api, this.ref);

  Future<WarehouseModel> createWarehouse({
    required String name,
    String? address,
    String? phone,
    bool isMain = false,
    String type = 'PHYSICAL',
  }) async {
    try {
      final response = await api.client.post(
        '/warehouses',
        data: {
          'name': name,
          if (address != null && address.isNotEmpty) 'address': address,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'is_main': isMain,
          'type': type,
          'is_active': true,
        },
      );
      ref.invalidate(warehouseListProvider);
      return WarehouseModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<WarehouseModel> updateWarehouse({
    required int id,
    required String name,
    String? address,
    String? phone,
    required bool isMain,
    required bool isActive,
    required String type,
  }) async {
    try {
      final response = await api.client.put(
        '/warehouses/$id',
        data: {
          'name': name,
          'address': address,
          'phone': phone,
          'is_main': isMain,
          'is_active': isActive,
          'type': type,
        },
      );
      ref.invalidate(warehouseListProvider);
      return WarehouseModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteWarehouse(int id) async {
    try {
      await api.client.delete('/warehouses/$id');
      ref.invalidate(warehouseListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}

