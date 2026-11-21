import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';

final auditLogsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onAuditLogEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received for auditLogsProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-audit-logs', onAuditLogEvent);
  final reconnectSub = pusher.onReconnected.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    reconnectSub.cancel();
    pusher.unsubscribeFromChannel('private-audit-logs', onAuditLogEvent);
  });

  try {
    final response = await api.client.get('/audit-logs');
    if (response.statusCode == 200) {
      final data = response.data;
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
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

final singleAuditLogProvider = FutureProvider.family<dynamic, int>((
  ref,
  id,
) async {
  final api = ref.watch(apiClientProvider);
  final pusher = ref.watch(pusherServiceProvider);

  void onSingleAuditEvent(Map<String, dynamic> eventData) {
    debugPrint("Realtime update received for singleAuditLogProvider: $eventData");
    ref.invalidateSelf();
  }

  pusher.subscribeToChannel('private-audit-logs', onSingleAuditEvent);
  final reconnectSub = pusher.onReconnected.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    reconnectSub.cancel();
    pusher.unsubscribeFromChannel('private-audit-logs', onSingleAuditEvent);
  });

  try {
    final response = await api.client.get('/audit-logs/$id');
    if (response.statusCode == 200) {
      final resData = response.data;
      final data = (resData is Map && resData.containsKey('data')) ? resData['data'] : resData;
      if (data is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed single audit log response payload)',
        );
      }
      return data;
    }
    throw Exception(
      'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
    );
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

class EntityAuditParam {
  final String entityType;
  final int entityId;
  EntityAuditParam(this.entityType, this.entityId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityAuditParam &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          entityId == other.entityId;

  @override
  int get hashCode => entityType.hashCode ^ entityId.hashCode;
}

final entityAuditLogsProvider =
    FutureProvider.family<List<dynamic>, EntityAuditParam>((ref, param) async {
      final api = ref.watch(apiClientProvider);
      final pusher = ref.watch(pusherServiceProvider);

      void onEntityAuditEvent(Map<String, dynamic> eventData) {
        final targetType = eventData['entity_type']?.toString();
        final targetId = int.tryParse(eventData['entity_id']?.toString() ?? '');
        if (targetType != null &&
            targetType != param.entityType &&
            targetId != param.entityId) {
          return;
        }
        debugPrint("Realtime update received for entityAuditLogsProvider: $eventData");
        ref.invalidateSelf();
      }

      pusher.subscribeToChannel('private-audit-logs', onEntityAuditEvent);
      final reconnectSub = pusher.onReconnected.listen((_) {
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        reconnectSub.cancel();
        pusher.unsubscribeFromChannel('private-audit-logs', onEntityAuditEvent);
      });

      try {
        final response = await api.client.get(
          '/audit-logs/entity/${param.entityType}/${param.entityId}',
        );
        if (response.statusCode == 200) {
          final data = response.data;
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
          throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed entity audit log response payload)');
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });
