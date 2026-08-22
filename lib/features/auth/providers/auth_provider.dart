import 'package:dio/dio.dart';
// ignore: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../models/user_model.dart';

// دۆخەکانی (State) چوونەژوورەوە
class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;

  AuthState({this.isLoading = false, this.error, this.user});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState());

  Future<bool> login(String phone, String password) async {
    state = AuthState(isLoading: true);

    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'phone': phone,
          'password': password,
          'device_name': 'Mobile App',
        },
      );

      final token = response.data['data']['token'];
      final userData = response.data['data']['user'];

      // سەیڤکردنی تۆکن لەناو مۆبایلەکە
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      state = AuthState(
        isLoading: false,
        user: UserModel.fromJson(userData, token),
      );

      return true; // لۆگین سەرکەوتوو بوو
    } on DioException catch (e) {
      String errorMessage = 'کێشەیەک ڕوویدا لە پەیوەندیکردن بە سێرڤەر';
      if (e.response != null && e.response?.data != null) {
        // هێنانەوەی نامەی هەڵەی لاراڤێڵ (Validation Errors)
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      state = AuthState(isLoading: false, error: errorMessage);
      return false; // لۆگین سەرکەوتوو نەبوو
    }
  }
}

// پێشکەشکردنی AuthNotifier بە UI
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiProvider));
});
