import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/route_model.dart';

final routeListProvider = FutureProvider<List<RouteModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/routes');
    if (response.statusCode == 200) {
      var rawData = response.data['data'];
      List data = [];
      if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
        data = rawData['data'] ?? [];
      } else if (rawData is List) {
        data = rawData;
      }
      return data.map((json) => RouteModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final routeActionsProvider = Provider<RouteActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return RouteActions(api, ref);
});

class RouteActions {
  final ApiClient api;
  final Ref ref;

  RouteActions(this.api, this.ref);

  Future<RouteModel> addRoute({
    required String name,
    required String code,
    String? description,
    String? color,
    bool isActive = true,
  }) async {
    try {
      final response = await api.client.post('/routes', data: {
        'name': name,
        'code': code,
        if (description != null) 'description': description,
        if (color != null) 'color': color,
        'is_active': isActive,
      });
      ref.invalidate(routeListProvider);
      return RouteModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<RouteModel> updateRoute(
    int id, {
    required String name,
    required String code,
    String? description,
    String? color,
    bool? isActive,
  }) async {
    try {
      final response = await api.client.put('/routes/$id', data: {
        'name': name,
        'code': code,
        if (description != null) 'description': description,
        if (color != null) 'color': color,
        if (isActive != null) 'is_active': isActive,
      });
      ref.invalidate(routeListProvider);
      return RouteModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteRoute(int id) async {
    try {
      await api.client.delete('/routes/$id');
      ref.invalidate(routeListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> assignSalesman(int routeId, int salesmanId, {String? workDate}) async {
    try {
      await api.client.post('/routes/$routeId/assign-salesman', data: {
        'salesman_id': salesmanId,
        if (workDate != null) 'work_date': workDate,
      });
      ref.invalidate(routeListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> removeSalesman(int routeId, int salesmanId) async {
    try {
      await api.client.delete('/routes/$routeId/remove-salesman/$salesmanId');
      ref.invalidate(routeListProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchSalesmenList() async {
    try {
      final response = await api.client.get('/salesmen');
      if (response.statusCode == 200 && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchRouteCustomers(int routeId) async {
    try {
      final response = await api.client.get('/routes/$routeId/customers');
      if (response.statusCode == 200 && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}

