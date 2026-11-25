import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../auth/providers/auth_provider.dart';

class AuditLogsNotifier extends AsyncNotifier<List<dynamic>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<dynamic>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onAuditLogEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for auditLogsProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-audit-logs', onAuditLogEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-audit-logs', onAuditLogEvent);
    });

    return _fetchAuditLogs(api);
  }

  Future<List<dynamic>> _fetchAuditLogs(ApiClient api) async {
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
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchAuditLogs(api);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current audit logs on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final auditLogsProvider = AsyncNotifierProvider<AuditLogsNotifier, List<dynamic>>(
  AuditLogsNotifier.new,
);

class SingleAuditLogNotifier extends FamilyAsyncNotifier<dynamic, int> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<dynamic> build(int arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return null;
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onSingleAuditEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received for singleAuditLogProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-audit-logs', onSingleAuditEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-audit-logs', onSingleAuditEvent);
    });

    return _fetchSingle(api, arg);
  }

  Future<dynamic> _fetchSingle(ApiClient api, int id) async {
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
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchSingle(api, arg);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current audit entry on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final singleAuditLogProvider =
    AsyncNotifierProvider.family<SingleAuditLogNotifier, dynamic, int>(
  SingleAuditLogNotifier.new,
);

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

class EntityAuditLogsNotifier
    extends FamilyAsyncNotifier<List<dynamic>, EntityAuditParam> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<dynamic>> build(EntityAuditParam arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onEntityAuditEvent(Map<String, dynamic> eventData) {
      final targetType = eventData['entity_type']?.toString();
      final targetId = int.tryParse(eventData['entity_id']?.toString() ?? '');
      if (targetType != null &&
          targetType != arg.entityType &&
          targetId != arg.entityId) {
        return;
      }
      debugPrint("Realtime update received for entityAuditLogsProvider: $eventData");
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-audit-logs', onEntityAuditEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-audit-logs', onEntityAuditEvent);
    });

    return _fetchEntityLogs(api, arg);
  }

  Future<List<dynamic>> _fetchEntityLogs(
    ApiClient api,
    EntityAuditParam param,
  ) async {
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
  }

  Future<void> refreshSilently() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchEntityLogs(api, arg);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current entity audit logs on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final entityAuditLogsProvider = AsyncNotifierProvider.family<
    EntityAuditLogsNotifier, List<dynamic>, EntityAuditParam>(
  EntityAuditLogsNotifier.new,
);
