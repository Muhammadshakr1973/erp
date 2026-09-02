import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../shared/models/commission_model.dart';

final commissionsListProvider =
    FutureProvider.family<List<CommissionModel>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/commissions',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data['data'] ?? response.data;
          final List items;
          if (resData is List) {
            items = resData;
          } else if (resData is Map && resData['data'] is List) {
            items = resData['data'];
          } else {
            throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commissions list response payload)');
          }
          return items
              .map(
                (json) =>
                    CommissionModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

final commissionSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/commissions/summary',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data['data'] ?? response.data;
          if (resData is Map<String, dynamic>) {
            return resData;
          } else if (resData is Map) {
            return Map<String, dynamic>.from(resData);
          }
          throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission summary response payload)');
        }
        throw Exception(
          'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        );
      } catch (e) {
        throw Exception(api.parseError(e));
      }
    });

final commissionDetailProvider = FutureProvider.family<CommissionModel, int>((
  ref,
  commissionId,
) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/commissions/$commissionId');
    if (response.statusCode == 200) {
      return CommissionModel.fromJson(response.data['data']);
    }
    throw Exception('کۆمسیۆن نەدۆزرایەوە');
  } catch (e) {
    throw Exception(api.parseError(e));
  }
});

class CommissionActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  CommissionActionNotifier(this._api, this._ref)
    : super(const AsyncValue.data(null));

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
      throw FormatException('داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed commission preview response payload)');
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
      state = const AsyncValue.data(null);
      _ref.invalidate(commissionsListProvider);
      _ref.invalidate(commissionSummaryProvider);
      return CommissionModel.fromJson(response.data['data']);
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
      state = const AsyncValue.data(null);
      _ref.invalidate(commissionsListProvider);
      _ref.invalidate(commissionSummaryProvider);
      _ref.invalidate(commissionDetailProvider(commissionId));
      return CommissionModel.fromJson(response.data['data']);
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
      state = const AsyncValue.data(null);
      _ref.invalidate(commissionsListProvider);
      _ref.invalidate(commissionSummaryProvider);
      _ref.invalidate(commissionDetailProvider(commissionId));
      return CommissionModel.fromJson(response.data['data']);
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
      state = const AsyncValue.data(null);
      _ref.invalidate(commissionsListProvider);
      _ref.invalidate(commissionSummaryProvider);
      _ref.invalidate(commissionDetailProvider(commissionId));
      return CommissionModel.fromJson(response.data['data']);
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
