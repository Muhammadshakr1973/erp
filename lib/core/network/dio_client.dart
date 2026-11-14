import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_constants.dart';

class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final currentBaseUrl = ApiConstants.baseUrl;
          options.baseUrl = currentBaseUrl;
          _dio.options.baseUrl = currentBaseUrl;

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final remoteDomain = response.headers.value('x-server-domain');
          if (remoteDomain != null) {
            unawaited(ApiConstants.syncFromBackendDomain(remoteDomain));
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          // Handle global errors here if needed
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
