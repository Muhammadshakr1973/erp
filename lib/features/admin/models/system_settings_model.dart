class SystemSettingsModel {
  final String companyName;
  final String companyPhone;
  final String companyAddress;
  final String receiptFooterText;
  final bool whatsappEnabled;
  final bool whatsappEnvEnabled;
  final String whatsappProvider;
  final String whatsappApiUrl;
  final bool whatsappApiTokenConfigured;
  final bool fcmServerKeyConfigured;
  final double defaultCommissionRate;
  final int defaultCreditLimit;
  final int lowStockDefaultThreshold;
  final bool requireOrderNotes;

  const SystemSettingsModel({
    required this.companyName,
    required this.companyPhone,
    required this.companyAddress,
    required this.receiptFooterText,
    required this.whatsappEnabled,
    required this.whatsappEnvEnabled,
    required this.whatsappProvider,
    required this.whatsappApiUrl,
    required this.whatsappApiTokenConfigured,
    required this.fcmServerKeyConfigured,
    required this.defaultCommissionRate,
    required this.defaultCreditLimit,
    required this.lowStockDefaultThreshold,
    required this.requireOrderNotes,
  });

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      companyName:
          json['company_name']?.toString() ?? 'کۆمپانیای گەردی (GARDI ERP)',
      companyPhone: json['company_phone']?.toString() ?? '',
      companyAddress: json['company_address']?.toString() ?? '',
      receiptFooterText:
          json['receipt_footer_text']?.toString() ?? 'سوپاس بۆ مامەڵەکردنتان',
      whatsappEnabled: _parseBool(json['whatsapp_enabled']),
      whatsappEnvEnabled: _parseBool(json['whatsapp_env_enabled']),
      whatsappProvider:
          json['whatsapp_provider']?.toString() ?? 'unconfigured',
      whatsappApiUrl: json['whatsapp_api_url']?.toString() ?? '',
      whatsappApiTokenConfigured:
          _parseBool(json['whatsapp_api_token_configured']),
      fcmServerKeyConfigured: _parseBool(json['fcm_server_key_configured']),
      defaultCommissionRate:
          double.tryParse(json['default_commission_rate']?.toString() ?? '') ??
              0.0,
      defaultCreditLimit:
          int.tryParse(json['default_credit_limit']?.toString() ?? '') ?? 0,
      lowStockDefaultThreshold:
          int.tryParse(json['low_stock_default_threshold']?.toString() ?? '') ??
              10,
      requireOrderNotes: _parseBool(json['require_order_notes']),
    );
  }

  static bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is num) return val == 1;
    final str = val?.toString().toLowerCase().trim();
    return str == '1' || str == 'true';
  }
}
