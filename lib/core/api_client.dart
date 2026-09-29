import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network/api_constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;

  static String get baseUrl => ApiConstants.baseUrl;

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
        validateStatus: (status) => status != null && status < 500,
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

  // Helper to extract error message from response data directly
  String extractErrorMessage(dynamic data, {String defaultMsg = 'ژمارەی مۆبایل یان وشەی نهێنی هەڵەیە'}) {
    if (data is Map) {
      if (data['errors'] != null && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            return firstError.first.toString();
          } else if (firstError != null) {
            return firstError.toString();
          }
        }
      }
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
    }
    return defaultMsg;
  }

  // Error parser helper
  String parseError(dynamic error) {
    if (error is DioException) {
      if (error.response != null && error.response!.data != null) {
        return extractErrorMessage(error.response!.data, defaultMsg: error.message ?? 'هەڵەی نادیار');
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
    } else if (error is Map) {
      return extractErrorMessage(error);
    }
    return error.toString();
  }
}
