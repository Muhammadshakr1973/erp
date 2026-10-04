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
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
        onError: (DioException e, handler) async {
          // Handle 401 Unauthorized globally to protect client session
          // 403 Forbidden means insufficient permissions, but the session is still valid
          if (e.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            await prefs.remove('current_user');
          }

          // Retry logic for GET request timeouts (safe, idempotent, prevents startup timeouts)
          if (e.requestOptions.method.toUpperCase() == 'GET' &&
              (e.type == DioExceptionType.connectionTimeout ||
               e.type == DioExceptionType.receiveTimeout ||
               e.type == DioExceptionType.sendTimeout)) {
            
            final extra = Map<String, dynamic>.from(e.requestOptions.extra);
            final retryCount = extra['retry_count'] ?? 0;
            if (retryCount < 2) {
              extra['retry_count'] = retryCount + 1;
              e.requestOptions.extra = extra;
              
              // Wait 2 seconds before retrying to let the server wake up
              await Future.delayed(const Duration(seconds: 2));
              try {
                final response = await _dio.fetch(e.requestOptions);
                return handler.resolve(response);
              } catch (err) {
                if (err is DioException) {
                  return handler.next(err);
                }
                return handler.next(DioException(requestOptions: e.requestOptions, error: err));
              }
            }
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
            final str = firstError.first.toString();
            if (str.toLowerCase().contains('phone') && (str.toLowerCase().contains('taken') || str.toLowerCase().contains('unique') || str.toLowerCase().contains('already'))) {
              return 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە';
            }
            return str;
          } else if (firstError != null) {
            final str = firstError.toString();
            if (str.toLowerCase().contains('phone') && (str.toLowerCase().contains('taken') || str.toLowerCase().contains('unique') || str.toLowerCase().contains('already'))) {
              return 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە';
            }
            return str;
          }
        }
      }
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        final msg = data['message'].toString();
        if (msg.toLowerCase().contains('phone') && (msg.toLowerCase().contains('taken') || msg.toLowerCase().contains('unique') || msg.toLowerCase().contains('already'))) {
          return 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە';
        }
        return msg;
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
