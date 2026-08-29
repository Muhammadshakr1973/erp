import 'package:flutter/material.dart';

import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';

class AppNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      isRead: json['is_read'] as bool? ?? (json['read_at'] != null),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AppNotification copyWith({
    int? id,
    int? userId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeAgoKurdish {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) {
      return 'پێش کەمێک';
    } else if (diff.inMinutes < 60) {
      return 'پێش ${diff.inMinutes} خولەک';
    } else if (diff.inHours < 24) {
      return 'پێش ${diff.inHours} کاتژمێر';
    } else if (diff.inDays < 7) {
      return 'پێش ${diff.inDays} ڕۆژ';
    } else {
      return '${createdAt.year}/${createdAt.month}/${createdAt.day}';
    }
  }

  String get typeLabelKurdish {
    switch (type.toLowerCase()) {
      case 'order':
        return 'پسوڵە';
      case 'payment':
        return 'پارەدان';
      case 'stock':
        return 'ستۆک و کۆگا';
      case 'commission':
        return 'کۆمسیۆن';
      case 'system':
      default:
        return 'سیستەم';
    }
  }

  IconData get iconData {
    switch (type.toLowerCase()) {
      case 'order':
        return AppIcons.order;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'stock':
        return Icons.inventory_2_outlined;
      case 'commission':
        return Icons.monetization_on_outlined;
      case 'system':
      default:
        return AppIcons.notifications;
    }
  }

  Color get iconColor {
    switch (type.toLowerCase()) {
      case 'order':
        return AppColors.primary;
      case 'payment':
        return AppColors.success;
      case 'stock':
        return AppColors.warning;
      case 'commission':
        return AppColors.info;
      case 'system':
      default:
        return AppColors.textSecondaryLight;
    }
  }
}

class WhatsAppLog {
  final int id;
  final int? customerId;
  final int? supplierId;
  final String recipientPhone;
  final String? recipientName;
  final String notificationType;
  final String? referenceType;
  final int? referenceId;
  final String message;
  final String status;
  final String? provider;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime createdAt;

  const WhatsAppLog({
    required this.id,
    this.customerId,
    this.supplierId,
    required this.recipientPhone,
    this.recipientName,
    required this.notificationType,
    this.referenceType,
    this.referenceId,
    required this.message,
    required this.status,
    this.provider,
    this.errorMessage,
    this.sentAt,
    required this.createdAt,
  });

  factory WhatsAppLog.fromJson(Map<String, dynamic> json) {
    return WhatsAppLog(
      id: json['id'] as int? ?? 0,
      customerId: json['customer_id'] as int?,
      supplierId: json['supplier_id'] as int?,
      recipientPhone: json['recipient_phone'] as String? ?? '',
      recipientName: json['recipient_name'] as String?,
      notificationType: json['notification_type'] as String? ?? 'GENERAL',
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      provider: json['provider'] as String?,
      errorMessage: json['error_message'] as String?,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get statusLabelKurdish {
    switch (status.toUpperCase()) {
      case 'SENT':
        return 'نێردرا';
      case 'SIMULATED':
        return 'تۆمارکرا (ئامادەکاری)';
      case 'PENDING':
        return 'لە چاوەڕوانی';
      case 'FAILED':
        return 'سەرکەوتوو نەبوو';
      default:
        return status;
    }
  }

  StatusBadgeType get statusBadgeType {
    switch (status.toUpperCase()) {
      case 'SENT':
        return StatusBadgeType.success;
      case 'SIMULATED':
        return StatusBadgeType.info;
      case 'PENDING':
        return StatusBadgeType.warning;
      case 'FAILED':
        return StatusBadgeType.danger;
      default:
        return StatusBadgeType.neutral;
    }
  }
}
