import 'package:flutter/material.dart';

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
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
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
      case 'customer':
        return 'کڕیار';
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
      case 'customer':
        return AppIcons.customers;
      case 'system':
      default:
        return AppIcons.notifications;
    }
  }

  Color get iconColor {
    switch (type.toLowerCase()) {
      case 'order':
        return AppColors.info;
      case 'payment':
        return AppColors.success;
      case 'stock':
        return AppColors.warning;
      case 'commission':
        return AppColors.info;
      case 'customer':
        return AppColors.purple;
      case 'system':
      default:
        return AppColors.textSecondary;
    }
  }

  Color iconColorAdaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type.toLowerCase()) {
      case 'order':
        return isDark ? AppColors.primaryDark : AppColors.primary;
      case 'payment':
        return isDark ? AppColors.successDark : AppColors.success;
      case 'stock':
        return isDark ? AppColors.warningDark : AppColors.warning;
      case 'commission':
        return isDark ? AppColors.infoDark : AppColors.info;
      case 'customer':
        return isDark ? AppColors.purpleDark : AppColors.purple;
      case 'system':
      default:
        return isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    }
  }
}
