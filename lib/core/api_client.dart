import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;

  static String get baseUrl {
    // Allows injecting production URL during build: flutter build apk --dart-define=API_URL=https://api.gardierp.com/api/v1
    const String envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    return 'http://127.0.0.1:8000/api/v1';
  }

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Retrieve token from storage
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Handle 401 Unauthorized globally to protect client session
          // 403 Forbidden means insufficient permissions, but the session is still valid
          if (e.response?.statusCode == 401) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.remove('auth_token');
              prefs.remove('current_user');
            });
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;

  // Error parser helper
  String parseError(dynamic error) {
    if (error is DioException) {
      if (error.response != null && error.response!.data != null) {
        try {
          final data = error.response!.data;
          if (data is Map) {
            if (data['errors'] != null && data['errors'] is Map) {
              final errors = data['errors'] as Map;
              if (errors.isNotEmpty) {
                final firstError = errors.values.first;
                if (firstError is List && firstError.isNotEmpty) {
                  return firstError.first.toString();
                }
              }
            }
            if (data['message'] != null) {
              return data['message'].toString();
            }
          }
        } catch (_) {}
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'پەیوەندی بە سێرڤەرەوە پچڕا. تکایە دووبارە هەوڵ بدەرەوە.';
        case DioExceptionType.connectionError:
          return 'هێڵی ئینتەرنێتت پچڕاوە.';
        default:
          return 'هەڵەیەک ڕوویدا: ${error.message ?? 'هەڵەی نادیار'}';
      }
    }
    return error.toString();
  }
}
