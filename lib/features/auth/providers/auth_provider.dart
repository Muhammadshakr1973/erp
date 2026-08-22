import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/user_model.dart';
import 'dart:convert';

// State for Auth
class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;

  AuthState({this.isLoading = false, this.user, this.error});

  AuthState copyWith({bool? isLoading, UserModel? user, String? error}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(AuthState()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('current_user');
    if (userStr != null) {
      state = state.copyWith(user: UserModel.fromJson(jsonDecode(userStr)));
    }
  }

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    // --- MOCK LOGIN FOR TESTING IN PREVIEW ---
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network
    
    if (phone == '1' || phone == '07500000000') {
      final user = UserModel(id: 1, name: 'خاوەندارێت (ئادمین)', phone: phone, role: 'owner');
      await _saveMockUser(user);
      return true;
    } else if (phone == '2' || phone == '07501111111') {
      final user = UserModel(id: 2, name: 'مەندوب (Salesman)', phone: phone, role: 'salesman');
      await _saveMockUser(user);
      return true;
    }
    // -----------------------------------------

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final userData = response.data['user'];

        final user = UserModel.fromJson(userData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('current_user', jsonEncode(user.toJson()));

        state = state.copyWith(isLoading: false, user: user);
        return true;
      }
    } catch (e) {
      final errorMsg = ref.read(apiClientProvider).parseError(e);
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    }
    
    state = state.copyWith(isLoading: false, error: 'هەڵەیەکی نەزانراو ڕوویدا');
    return false;
  }

  Future<void> _saveMockUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'mock_token_123');
    await prefs.setString('current_user', jsonEncode(user.toJson()));
    state = state.copyWith(isLoading: false, user: user);
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiClientProvider);
      await api.client.post('/auth/logout');
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
    
    state = AuthState(); // Reset state
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
