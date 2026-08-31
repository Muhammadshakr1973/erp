import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiConstants {
  // If running on Android emulator, localhost is 10.0.2.2
  // For iOS simulator or desktop/web, it's 127.0.0.1
  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    return 'http://127.0.0.1:8000/api/v1';
  }

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
  static const String whatsAppLogs = '/notifications/whatsapp-logs';
}
