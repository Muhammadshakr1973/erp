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
  final List<int> keeperIds;
  final List<int> salesmanIds;
  final List<String> keeperNames;
  final List<String> salesmanNames;
  final int? cashVanUserId;
  final String? cashVanUserName;

  WarehouseModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isMain = false,
    this.isActive = true,
    this.type = 'PHYSICAL_DIRECT',
    this.stocksCount = 0,
    this.keeperIds = const [],
    this.salesmanIds = const [],
    this.keeperNames = const [],
    this.salesmanNames = const [],
    this.cashVanUserId,
    this.cashVanUserName,
  });

  bool get isVan => type.toUpperCase() == 'VAN' || name.contains('کاشڤان');
  bool get isReserve => type.toUpperCase() == 'PHYSICAL_RESERVE';
  bool get isDirectSale =>
      type.toUpperCase() == 'PHYSICAL_DIRECT' ||
      (type.toUpperCase() == 'PHYSICAL' && !isVan && !isReserve);
  bool get isPhysical => !isVan;
  bool get canSell => !isReserve;

  String get typeDisplayName {
    if (isVan) return 'ئۆتۆمبێلی کاشڤان (گەڕۆک)';
    if (isReserve) return 'کۆگای فیزیکی - یەدەگ (تەنها پڕکردنەوە)';
    return 'کۆگای فیزیکی - فرۆشتنی ڕاستەوخۆ';
  }

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toUpperCase() ?? 'PHYSICAL_DIRECT';
    final normalizedType = rawType == 'PHYSICAL' ? 'PHYSICAL_DIRECT' : rawType;

    final keeperIdsList = (json['keeper_ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    final salesmanIdsList = (json['salesman_ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    final keeperNamesList =
        (json['keeper_names'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final salesmanNamesList =
        (json['salesman_names'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return WarehouseModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      isMain: json['is_main'] == true || json['is_main'] == 1,
      isActive: json['is_active'] != false && json['is_active'] != 0,
      type: normalizedType,
      stocksCount: (json['stocks_count'] as num?)?.toInt() ?? 0,
      keeperIds: keeperIdsList,
      salesmanIds: salesmanIdsList,
      keeperNames: keeperNamesList,
      salesmanNames: salesmanNamesList,
      cashVanUserId: (json['cash_van_user_id'] as num?)?.toInt(),
      cashVanUserName: json['cash_van_user_name']?.toString(),
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
      'keeper_ids': keeperIds,
      'salesman_ids': salesmanIds,
      'cash_van_user_id': cashVanUserId,
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
    bool isMain = false,
    required String type,
    int? cashVanUserId,
    List<int>? keeperIds,
    List<int>? salesmanIds,
  }) async {
    try {
      final response = await api.client.post(
        '/warehouses',
        data: {
          'name': name,
          if (address != null && address.isNotEmpty) 'address': address,
          'is_main': isMain,
          'type': type,
          'is_active': true,
          if (cashVanUserId != null) 'cash_van_user_id': cashVanUserId,
          if (keeperIds != null) 'keeper_ids': keeperIds,
          if (salesmanIds != null) 'salesman_ids': salesmanIds,
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
    required bool isMain,
    required bool isActive,
    required String type,
    int? cashVanUserId,
    List<int>? keeperIds,
    List<int>? salesmanIds,
  }) async {
    try {
      final response = await api.client.put(
        '/warehouses/$id',
        data: {
          'name': name,
          'address': address,
          'is_main': isMain,
          'is_active': isActive,
          'type': type,
          'cash_van_user_id': cashVanUserId,
          'keeper_ids': keeperIds ?? [],
          'salesman_ids': salesmanIds ?? [],
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
