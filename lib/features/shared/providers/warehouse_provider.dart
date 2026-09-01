import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class WarehouseModel {
  final int id;
  final String name;
  final bool isMain;

  WarehouseModel({required this.id, required this.name, this.isMain = false});

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isMain: json['is_main'] == true || json['is_main'] == 1,
    );
  }
}

final warehouseListProvider = FutureProvider<List<WarehouseModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.client.get('/warehouses');
  if (response.statusCode == 200) {
    final List data = response.data['data'] ?? [];
    return data.map((json) => WarehouseModel.fromJson(json)).toList();
  }
  throw Exception('Failed to load warehouses');
});
