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
  try {
    final response = await api.client.get('/warehouses');
    if (response.statusCode == 200) {
      final resData = response.data;
      if (resData is! Map || resData['data'] is! List) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed warehouse response payload)',
        );
      }
      final List data = resData['data'] as List;
      return data.map((json) => WarehouseModel.fromJson(json)).toList();
    }
    throw Exception('سێرڤەر کۆدی نادروستی گەڕاندەوە: ${response.statusCode}');
  } catch (e) {
    // Explicitly rethrow to ensure API failure is observable as an error state
    throw Exception(api.parseError(e));
  }
});
