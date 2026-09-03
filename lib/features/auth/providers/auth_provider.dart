import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../models/user_model.dart';

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

String _getDeviceName() {
  if (kIsWeb) return 'Web';
  if (Platform.isAndroid) return 'Android Device';
  if (Platform.isIOS) return 'iOS Device';
  if (Platform.isWindows) return 'Windows Device';
  if (Platform.isMacOS) return 'macOS Device';
  if (Platform.isLinux) return 'Linux Device';
  return 'Unknown Device';
}


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

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.post(
        '/auth/login',
        data: {'phone': phone, 'password': password, 'device_name': _getDeviceName()},
      );

      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed auth response payload)');
        }
        final dataMap = resData['data'] as Map;
        final token = dataMap['token'];
        final userData = dataMap['user'];
        if (token is! String || userData is! Map) {
          throw FormatException('تۆکن یان زانیاری بەکارهێنەر لە وەڵامدا بەردەست نییە (Token or user object missing/malformed)');
        }

        final user = UserModel.fromJson(Map<String, dynamic>.from(userData));

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

  Future<bool> loginByBarcode(String barcode) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.post(
        '/auth/login',
        data: {'barcode': barcode, 'device_name': _getDeviceName()},
      );

      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed auth response payload)');
        }
        final dataMap = resData['data'] as Map;
        final token = dataMap['token'];
        final userData = dataMap['user'];
        if (token is! String || userData is! Map) {
          throw FormatException('تۆکن یان زانیاری بەکارهێنەر لە وەڵامدا بەردەست نییە (Token or user object missing/malformed)');
        }

        final user = UserModel.fromJson(Map<String, dynamic>.from(userData));

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

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      ref.read(pusherServiceProvider).disconnect();
    } catch (_) {}

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
