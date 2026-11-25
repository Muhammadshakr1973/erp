import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/models/commission_model.dart';

class CommissionsListNotifier
    extends FamilyAsyncNotifier<List<CommissionModel>, Map<String, dynamic>> {
  static final Set<Map<String, dynamic>> activeFilters = {};

  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<List<CommissionModel>> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    activeFilters.add(arg);

    void onCommissionsListEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-commissions for list: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-commissions', onCommissionsListEvent);
    pusher.subscribeToChannel('private-orders', onCommissionsListEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      activeFilters.remove(arg);
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel(
        'private-commissions',
        onCommissionsListEvent,
      );
      pusher.unsubscribeFromChannel('private-orders', onCommissionsListEvent);
    });

    return _fetchList(api, arg);
  }

  Future<List<CommissionModel>> _fetchList(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
    try {
      final response = await api.client.get(
        '/commissions',
        queryParameters: filters,
      );
      if (response.statusCode == 200) {
        final dynamic resData;
        if (response.data is Map && response.data.containsKey('data')) {
          resData = response.data['data'];
        } else {
          resData = response.data;
        }
        final List items;
        if (resData is List) {
          items = resData;
        } else if (resData is Map && resData['data'] is List) {
          items = resData['data'];
        } else {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commissions list response payload)',
          );
        }
        return items
            .whereType<Map>()
            .map(
              (json) => CommissionModel.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .toList();
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchList(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current commissions list on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final commissionsListProvider = AsyncNotifierProvider.family<
    CommissionsListNotifier, List<CommissionModel>, Map<String, dynamic>>(
  CommissionsListNotifier.new,
);

class CommissionSummaryNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>, Map<String, dynamic>> {
  static final Set<Map<String, dynamic>> activeFilters = {};

  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<Map<String, dynamic>> build(Map<String, dynamic> arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const {};
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    activeFilters.add(arg);

    void onCommissionSummaryEvent(Map<String, dynamic> eventData) {
      debugPrint(
        "Realtime update received on private-commissions for summary: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel(
      'private-commissions',
      onCommissionSummaryEvent,
    );
    pusher.subscribeToChannel('private-orders', onCommissionSummaryEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      activeFilters.remove(arg);
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel(
        'private-commissions',
        onCommissionSummaryEvent,
      );
      pusher.unsubscribeFromChannel(
        'private-orders',
        onCommissionSummaryEvent,
      );
    });

    return _fetchSummary(api, arg);
  }

  Future<Map<String, dynamic>> _fetchSummary(
    ApiClient api,
    Map<String, dynamic> filters,
  ) async {
    try {
      final response = await api.client.get(
        '/commissions/summary',
        queryParameters: filters,
      );
      if (response.statusCode == 200) {
        final dynamic resData;
        if (response.data is Map && response.data.containsKey('data')) {
          resData = response.data['data'];
        } else {
          resData = response.data;
        }
        if (resData is Map<String, dynamic>) {
          return resData;
        } else if (resData is Map) {
          return Map<String, dynamic>.from(resData);
        }
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission summary response payload)',
        );
      }
      throw Exception(
        'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
      );
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchSummary(api, arg);
      final current = state.valueOrNull;
      if (current != null && jsonEncode(current) == jsonEncode(fresh)) {
        return;
      }
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current summary on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }
}

final commissionSummaryProvider = AsyncNotifierProvider.family<
    CommissionSummaryNotifier, Map<String, dynamic>, Map<String, dynamic>>(
  CommissionSummaryNotifier.new,
);

class CommissionDetailNotifier extends FamilyAsyncNotifier<CommissionModel, int> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;

  @override
  FutureOr<CommissionModel> build(int arg) async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      throw Exception('بەکارهێنەر لۆگئۆت بووە (User is logged out)');
    }
    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onCommissionDetailEvent(Map<String, dynamic> eventData) {
      final eventCommissionId = int.tryParse(
        (eventData['commission_id'] ?? eventData['id'])?.toString() ?? '',
      );
      if (eventCommissionId != null && eventCommissionId != arg) {
        return;
      }
      debugPrint(
        "Realtime update received on private-commissions for detail #$arg: $eventData",
      );
      unawaited(refreshSilently());
    }

    pusher.subscribeToChannel('private-commissions', onCommissionDetailEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel(
        'private-commissions',
        onCommissionDetailEvent,
      );
    });

    return _fetchDetail(api, arg);
  }

  Future<CommissionModel> _fetchDetail(ApiClient api, int commissionId) async {
    try {
      final response = await api.client.get('/commissions/$commissionId');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! Map) {
          throw FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission detail response payload)',
          );
        }
        return CommissionModel.fromJson(
          Map<String, dynamic>.from(resData['data']),
        );
      }
      throw Exception('کۆمسیۆن نەدۆزرایەوە');
    } catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> refreshSilently() async {
    if (ref.read(authProvider).user == null) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final fresh = await _fetchDetail(api, arg);
      state = AsyncData(fresh);
    } catch (_) {
      // Preserve current detail on transient errors
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void setCommissionLocally(CommissionModel commission) {
    if (commission.id == arg) {
      state = AsyncData(commission);
    }
  }
}

final commissionDetailProvider =
    AsyncNotifierProvider.family<CommissionDetailNotifier, CommissionModel, int>(
      CommissionDetailNotifier.new,
    );

class CommissionActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  CommissionActionNotifier(this._api, this._ref)
    : super(const AsyncValue.data(null));

  void _refreshActiveListsAndSummarySilently() {
    for (final filters in List.of(CommissionsListNotifier.activeFilters)) {
      if (_ref.exists(commissionsListProvider(filters))) {
        unawaited(
          _ref.read(commissionsListProvider(filters).notifier).refreshSilently(),
        );
      }
    }
    for (final filters in List.of(CommissionSummaryNotifier.activeFilters)) {
      if (_ref.exists(commissionSummaryProvider(filters))) {
        unawaited(
          _ref
              .read(commissionSummaryProvider(filters).notifier)
              .refreshSilently(),
        );
      }
    }
  }

  Future<Map<String, dynamic>> previewEligibleOrders({
    required int salesmanId,
    required String periodFrom,
    required String periodTo,
  }) async {
    try {
      final response = await _api.client.get(
        '/commissions/preview',
        queryParameters: {
          'salesman_id': salesmanId,
          'period_from': periodFrom,
          'period_to': periodTo,
        },
      );
      final resData = response.data['data'] ?? response.data;
      if (resData is Map<String, dynamic>) {
        return resData;
      } else if (resData is Map) {
        return Map<String, dynamic>.from(resData);
      }
      throw FormatException(
        'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission preview response payload)',
      );
    } catch (e) {
      throw Exception(_api.parseError(e));
    }
  }

  Future<CommissionModel> calculateCommission({
    required int salesmanId,
    required String periodFrom,
    required String periodTo,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.client.post(
        '/commissions/calculate',
        data: {
          'salesman_id': salesmanId,
          'period_from': periodFrom,
          'period_to': periodTo,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission response payload)',
        );
      }
      final model = CommissionModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      state = const AsyncValue.data(null);
      _refreshActiveListsAndSummarySilently();
      return model;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw Exception(_api.parseError(e));
    }
  }

  Future<CommissionModel> approveCommission({
    required int commissionId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.client.post(
        '/commissions/$commissionId/approve',
        data: {if (notes != null && notes.isNotEmpty) 'notes': notes},
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission response payload)',
        );
      }
      final model = CommissionModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      state = const AsyncValue.data(null);
      _refreshActiveListsAndSummarySilently();
      if (_ref.exists(commissionDetailProvider(commissionId))) {
        _ref
            .read(commissionDetailProvider(commissionId).notifier)
            .setCommissionLocally(model);
      }
      return model;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw Exception(_api.parseError(e));
    }
  }

  Future<CommissionModel> payCommission({
    required int commissionId,
    String paymentMethod = 'cash',
    String? paidAt,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.client.post(
        '/commissions/$commissionId/pay',
        data: {
          'payment_method': paymentMethod,
          if (paidAt != null) 'paid_at': paidAt,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission response payload)',
        );
      }
      final model = CommissionModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      state = const AsyncValue.data(null);
      _refreshActiveListsAndSummarySilently();
      if (_ref.exists(commissionDetailProvider(commissionId))) {
        _ref
            .read(commissionDetailProvider(commissionId).notifier)
            .setCommissionLocally(model);
      }
      return model;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw Exception(_api.parseError(e));
    }
  }

  Future<CommissionModel> cancelCommission({
    required int commissionId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.client.post(
        '/commissions/$commissionId/cancel',
        data: {'reason': reason},
      );
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission response payload)',
        );
      }
      final model = CommissionModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      state = const AsyncValue.data(null);
      _refreshActiveListsAndSummarySilently();
      if (_ref.exists(commissionDetailProvider(commissionId))) {
        _ref
            .read(commissionDetailProvider(commissionId).notifier)
            .setCommissionLocally(model);
      }
      return model;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw Exception(_api.parseError(e));
    }
  }
}

final commissionActionProvider =
    StateNotifierProvider<CommissionActionNotifier, AsyncValue<void>>((ref) {
      return CommissionActionNotifier(ref.watch(apiClientProvider), ref);
    });
