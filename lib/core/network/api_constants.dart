class ApiConstants {
  // Production URL for the live backend on Hostinger
  // Can still be overridden via --dart-define=API_URL=...
  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    
    return 'https://pos.gardi.click/api/v1';
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
