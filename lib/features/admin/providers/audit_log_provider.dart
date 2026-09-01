import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

final auditLogsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/audit-logs');
    if (response.statusCode == 200) {
      final raw = response.data['data'];
      if (raw is List) {
        return raw;
      } else if (raw is Map && raw['data'] is List) {
        return raw['data'];
      }
      return [];
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
  try {
    final response = await api.client.get('/audit-logs/$id');
    if (response.statusCode == 200) {
      return response.data['data'] ?? response.data;
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
      try {
        final response = await api.client.get(
          '/audit-logs/entity/${param.entityType}/${param.entityId}',
        );
        if (response.statusCode == 200) {
          return response.data['data'] ?? [];
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });
