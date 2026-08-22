import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
    : dio = Dio(
        BaseOptions(
          // تێبینی: ئەگەر مۆبایلی ڕاستەقینە بەکاردەهێنیت، ئایپی کۆمپیوتەرەکەت بنووسە.
          // ئەگەر ئیمولەیتەری ئەندرۆیدە، 10.0.2.2 بەکاربهێنە.
          baseUrl: 'http://127.0.0.1:8000/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    // ئینتەرسێپتەر بۆ دانانی تۆکن لەسەر هەموو ڕیکوێستەکان
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}

// دابینکردنی ApiClient بۆ هەموو پڕۆژەکە لە ڕێگەی Riverpodـەوە
final apiProvider = Provider<ApiClient>((ref) => ApiClient());
