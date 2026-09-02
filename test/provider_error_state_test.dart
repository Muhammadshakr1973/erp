import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper function logic under test matching route_provider.dart
List<Map<String, dynamic>> parseListResponse(dynamic rawData) {
  if (rawData is List) {
    return List<Map<String, dynamic>>.from(rawData);
  }
  if (rawData is Map) {
    if (rawData.containsKey('data')) {
      final inner = rawData['data'];
      if (inner is List) {
        return List<Map<String, dynamic>>.from(inner);
      }
      if (inner is Map && inner.containsKey('data')) {
        final doubleInner = inner['data'];
        if (doubleInner is List) {
          return List<Map<String, dynamic>>.from(doubleInner);
        }
      }
    }
  }
  throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response structure)');
}

// Helper function logic under test matching audit_log_provider.dart
List<dynamic> parseAuditLogs(dynamic data) {
  if (data is List) {
    return data;
  }
  if (data is Map) {
    final raw = data['data'];
    if (raw is List) {
      return raw;
    } else if (raw is Map && raw['data'] is List) {
      return raw['data'];
    }
  }
  throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed audit log response payload)');
}

// Helper function logic under test matching commission_provider.dart
Map<String, dynamic> parseCommissionSummary(dynamic data) {
  final resData = data is Map && data.containsKey('data') && data['data'] is Map ? data['data'] : data;
  if (resData is Map<String, dynamic>) {
    return resData;
  } else if (resData is Map) {
    return Map<String, dynamic>.from(resData);
  }
  throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission summary response payload)');
}

// Network error check under test matching orders_provider.dart
bool isNetworkError(dynamic e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.response == null) {
      return true;
    }
    return false;
  }
  final errStr = e.toString().toLowerCase();
  if (errStr.contains('socketexception') ||
      errStr.contains('networkisunreachable') ||
      errStr.contains('connection refused')) {
    return true;
  }
  return false;
}

// Simulated provider fetch logic matching orders_provider.dart
List<String> simulateOrdersListFetch({
  required dynamic apiResult,
  required Response<dynamic>? httpResponse,
  required DioException? dioError,
  required List<String> localCache,
}) {
  try {
    if (dioError != null) {
      throw dioError;
    }
    if (httpResponse != null && httpResponse.statusCode == 200) {
      final resData = httpResponse.data is Map && httpResponse.data.containsKey('data')
          ? httpResponse.data['data']
          : httpResponse.data;
      if (resData is! List) {
        throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed response payload)');
      }
      return List<String>.from(resData.map((e) => e.toString()));
    }
    throw Exception('Server returned invalid code: ${httpResponse?.statusCode}');
  } catch (e) {
    if (isNetworkError(e)) {
      if (localCache.isNotEmpty) {
        return localCache;
      }
      throw Exception('No network connection and no cached orders');
    }
    if (e is DioException) {
      throw Exception('API Error: ${e.response?.statusCode}');
    }
    rethrow;
  }
}

void main() {
  group('Frontend Reliability & Parsing Scenarios', () {
    test('a) Valid 200 + empty list => empty success', () {
      final routeRes = parseListResponse([]);
      expect(routeRes, isEmpty);

      final paginatedRouteRes = parseListResponse({'data': []});
      expect(paginatedRouteRes, isEmpty);

      final auditRes = parseAuditLogs({'data': []});
      expect(auditRes, isEmpty);

      final orders = simulateOrdersListFetch(
        apiResult: null,
        httpResponse: Response(
          requestOptions: RequestOptions(path: '/orders'),
          statusCode: 200,
          data: {'data': []},
        ),
        dioError: null,
        localCache: [],
      );
      expect(orders, isEmpty);
    });

    test('b) Malformed 200 payload => error (throws FormatException)', () {
      expect(() => parseListResponse('invalid_string_payload'), throwsA(isA<FormatException>()));
      expect(() => parseListResponse({'data': 'not_a_list'}), throwsA(isA<FormatException>()));
      expect(() => parseAuditLogs({'data': 12345}), throwsA(isA<FormatException>()));
      expect(() => parseCommissionSummary('invalid_summary'), throwsA(isA<FormatException>()));

      expect(
        () => simulateOrdersListFetch(
          apiResult: null,
          httpResponse: Response(
            requestOptions: RequestOptions(path: '/orders'),
            statusCode: 200,
            data: {'data': 'corrupted_string_not_list'},
          ),
          dioError: null,
          localCache: ['cached_order_1'], // should NOT use cache on malformed 200!
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('c) HTTP 401/403/500 => error (no cache fallback)', () {
      final dio401 = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        response: Response(
          requestOptions: RequestOptions(path: '/orders'),
          statusCode: 401,
          data: {'message': 'Unauthenticated'},
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        () => simulateOrdersListFetch(
          apiResult: null,
          httpResponse: null,
          dioError: dio401,
          localCache: ['cached_order_1'], // Cache exists but must NOT be used on 401!
        ),
        throwsA(isA<Exception>()),
      );

      final dio500 = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        response: Response(
          requestOptions: RequestOptions(path: '/orders'),
          statusCode: 500,
          data: {'message': 'Server Error'},
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        () => simulateOrdersListFetch(
          apiResult: null,
          httpResponse: null,
          dioError: dio500,
          localCache: ['cached_order_1'],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('d) Genuine network failure with cache => cache fallback', () {
      final netError = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        type: DioExceptionType.connectionError,
        error: 'SocketException: Connection refused',
      );

      final orders = simulateOrdersListFetch(
        apiResult: null,
        httpResponse: null,
        dioError: netError,
        localCache: ['cached_order_1', 'cached_order_2'],
      );

      expect(orders, equals(['cached_order_1', 'cached_order_2']));
    });

    test('e) Genuine network failure without cache => error', () {
      final netError = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(
        () => simulateOrdersListFetch(
          apiResult: null,
          httpResponse: null,
          dioError: netError,
          localCache: [], // empty cache
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
