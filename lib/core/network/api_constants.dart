import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String defaultOrigin = 'https://pos.gardi.click';
  static const String _settingsBoxName = 'settings';
  static const String _domainKey = 'api_server_domain';
  static const String _domainSourceKey = 'api_server_domain_source';

  static bool _isSyncingRemoteDomain = false;
  static String? _lastFailedRemoteDomain;
  static DateTime? _lastFailedRemoteAt;

  static String get _fallbackOrigin {
    const String envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return normalizeOrigin(envUrl) ?? defaultOrigin;
    }
    return defaultOrigin;
  }

  /// Normalizes user-entered domain/URL into a clean origin (e.g. `https://pos.gardi.click`).
  /// Returns null if the input is empty or invalid.
  static String? normalizeOrigin(String rawInput) {
    var value = rawInput.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s'))) {
      return null;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final isLocalOrIp = value.startsWith('localhost') ||
          RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?(/.*)?$').hasMatch(value);
      value = '${isLocalOrIp ? 'http' : 'https'}://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    final isIpOrLocal = uri.host == 'localhost' ||
        RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(uri.host);
    if (!isIpOrLocal && !uri.host.contains('.')) {
      return null;
    }

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('/api/v1')) {
      path = path.substring(0, path.length - 7);
    } else if (lowerPath.endsWith('/api')) {
      path = path.substring(0, path.length - 4);
    }

    return '${uri.scheme}://${uri.authority}$path';
  }

  static String get serverOrigin {
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) {
        final box = Hive.box(_settingsBoxName);
        final saved = box.get(_domainKey);
        if (saved is String && saved.trim().isNotEmpty) {
          final normalized = normalizeOrigin(saved);
          if (normalized != null) {
            return normalized;
          }
        }
      }
    } catch (_) {}
    return _fallbackOrigin;
  }

  static bool get hasCustomDomain {
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) {
        final saved = Hive.box(_settingsBoxName).get(_domainKey);
        return saved is String && saved.trim().isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  static String? get _domainSource {
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) {
        final source = Hive.box(_settingsBoxName).get(_domainSourceKey);
        return source is String ? source : null;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> setCustomDomain(
    String rawInput, {
    String source = 'local',
  }) async {
    final normalized = normalizeOrigin(rawInput);
    if (normalized == null) {
      return 'تکایە دۆمەینێکی دروست بنووسە (نموونە: pos.gardi.click)';
    }

    final box = Hive.isBoxOpen(_settingsBoxName)
        ? Hive.box(_settingsBoxName)
        : await Hive.openBox(_settingsBoxName);
    await box.put(_domainKey, normalized);
    await box.put(_domainSourceKey, source);
    return null;
  }

  static Future<void> resetCustomDomain() async {
    final box = Hive.isBoxOpen(_settingsBoxName)
        ? Hive.box(_settingsBoxName)
        : await Hive.openBox(_settingsBoxName);
    await box.delete(_domainKey);
    await box.delete(_domainSourceKey);
  }

  /// Checks whether a candidate domain hosts a reachable GARDI ERP backend.
  static Future<bool> verifyServerDomain(String rawOrigin) async {
    final normalized = normalizeOrigin(rawOrigin);
    if (normalized == null) return false;

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final response = await dio.get('$normalized/api/v1/app-config');
      if (response.statusCode == 200 && response.data is Map) {
        return response.data['app'] == 'gardi_erp';
      }
    } catch (_) {}
    return false;
  }

  /// Fetches `/api/v1/app-config` on app startup so logged-out or freshly opened
  /// devices automatically receive any domain update configured by the Owner.
  static Future<void> fetchAndSyncAppConfig() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final response = await dio.get('$serverOrigin/api/v1/app-config');
      if (response.statusCode == 200 && response.data is Map) {
        final remoteDomain = response.data['server_domain']?.toString();
        await syncFromBackendDomain(remoteDomain);
      }
    } catch (_) {}
  }

  /// Applies a domain advertised by the backend (`X-Server-Domain` header or
  /// `/app-config`) only after verifying the target domain is live and healthy.
  static Future<void> syncFromBackendDomain(String? rawRemoteDomain) async {
    if (_isSyncingRemoteDomain) return;

    final trimmed = rawRemoteDomain?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (_domainSource == 'server' && hasCustomDomain) {
        await resetCustomDomain();
        await _clearPusherCache();
      }
      return;
    }

    final normalized = normalizeOrigin(trimmed);
    if (normalized == null || normalized == serverOrigin) {
      return;
    }

    if (_lastFailedRemoteDomain == normalized &&
        _lastFailedRemoteAt != null &&
        DateTime.now().difference(_lastFailedRemoteAt!) <
            const Duration(seconds: 30)) {
      return;
    }

    _isSyncingRemoteDomain = true;
    try {
      final isReachable = await verifyServerDomain(normalized);
      if (isReachable) {
        await setCustomDomain(normalized, source: 'server');
        await _clearPusherCache();
        _lastFailedRemoteDomain = null;
        _lastFailedRemoteAt = null;
      } else {
        _lastFailedRemoteDomain = normalized;
        _lastFailedRemoteAt = DateTime.now();
      }
    } finally {
      _isSyncingRemoteDomain = false;
    }
  }

  static Future<void> _clearPusherCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pusher_server_key');
      await prefs.remove('pusher_server_cluster');
    } catch (_) {}
  }

  // Dynamic API base URL resolved from custom domain setting or default
  static String get baseUrl => '$serverOrigin/api/v1';

  static const String appConfig = '/app-config';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String customers = '/customers';
  static const String orders = '/orders';
  static const String payments = '/payments';
  static const String stockTransfers = '/stock-transfers';
  static const String deliveryTrips = '/delivery-trips';
  static const String commissions = '/commissions';
  static const String purchaseOrders = '/purchase-orders';
  static const String reportsDashboard = '/reports/dashboard';
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsMarkAllRead = '/notifications/read';
  static const String deviceToken = '/device-token';
  static const String settings = '/settings';
  static const String settingsClearCache = '/settings/clear-cache';
}
