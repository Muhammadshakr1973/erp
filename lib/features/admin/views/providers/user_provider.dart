import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../auth/models/user_model.dart';

final userAdminProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/users');
    if (response.statusCode == 200) {
      final rawData = response.data['data'];
      final List usersList = rawData['users'] ?? [];
      final List rolesList = rawData['roles'] ?? [];
      return {
        'users': usersList.map((json) => UserModel.fromJson(json)).toList(),
        'roles': rolesList, // e.g. [{id: 1, name: "owner", display_name: "خاوەن کار"}, ...]
      };
    }
    return {'users': <UserModel>[], 'roles': []};
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final salesmenListProvider = FutureProvider<List<UserModel>>((ref) async {
  final userData = await ref.watch(userAdminProvider.future);
  final List<UserModel> allUsers =
      (userData['users'] as List<dynamic>?)?.cast<UserModel>() ?? [];
  return allUsers.where((u) => u.role.toLowerCase() == 'salesman').toList();
});

final userActionsProvider = Provider<UserActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return UserActions(api, ref);
});

class UserActions {
  final ApiClient api;
  final Ref ref;

  UserActions(this.api, this.ref);

  Future<void> addUser({
    required String name,
    required String phone,
    required String password,
    required int roleId,
    double? commissionRate,
    String? barcode,
    bool? isActive,
  }) async {
    try {
      await api.client.post(
        '/users',
        data: {
          'name': name,
          'phone': phone,
          'password': password,
          'role_id': roleId,
          if (commissionRate != null) 'commission_rate': commissionRate,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          if (isActive != null) 'is_active': isActive,
        },
      );
      ref.invalidate(userAdminProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> updateUser(
    int id, {
    required String name,
    required String phone,
    String? password,
    required int roleId,
    double? commissionRate,
    String? barcode,
    bool? isActive,
  }) async {
    try {
      await api.client.put(
        '/users/$id',
        data: {
          'name': name,
          'phone': phone,
          if (password != null && password.isNotEmpty) 'password': password,
          'role_id': roleId,
          if (commissionRate != null) 'commission_rate': commissionRate,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          if (isActive != null) 'is_active': isActive,
        },
      );
      ref.invalidate(userAdminProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await api.client.delete('/users/$id');
      ref.invalidate(userAdminProvider);
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
