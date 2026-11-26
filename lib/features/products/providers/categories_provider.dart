import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/category_model.dart';
import 'products_provider.dart';

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  bool _isRefreshing = false;
  bool _pendingRefresh = false;
  bool _disposed = false;

  @override
  Future<List<CategoryModel>> build() async {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) return const [];

    final api = ref.watch(apiClientProvider);
    final pusher = ref.watch(pusherServiceProvider);

    void onCategoriesEvent(Map<String, dynamic> eventData) {
      debugPrint("Realtime update received on private-categories: $eventData");
      _handleRealtimeEvent(eventData);
    }

    pusher.subscribeToChannel('private-categories', onCategoriesEvent);
    final reconnectSub = pusher.onReconnected.listen((_) {
      unawaited(refreshSilently());
    });
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      reconnectSub.cancel();
      pusher.unsubscribeFromChannel('private-categories', onCategoriesEvent);
    });

    try {
      final response = await api.client.get('/categories');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData is! Map || resData['data'] is! List) {
          throw const FormatException(
            'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed categories response payload)',
          );
        }
        final List data = resData['data'] as List;
        return data.map((json) => CategoryModel.fromJson(json)).toList();
      }
      throw Exception(
        api.extractErrorMessage(
          response.data,
          defaultMsg:
              'سێرڤەر کۆدی نادروستی گەڕاندەوە (Server returned invalid code): ${response.statusCode}',
        ),
      );
    } on DioException catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> eventData) {
    final eventType = eventData['event_type']?.toString() ?? '';
    final rawCategoryId = eventData['category_id'];
    final categoryId = rawCategoryId is int
        ? rawCategoryId
        : int.tryParse(rawCategoryId?.toString() ?? '');

    if (eventType == 'delete') {
      if (categoryId != null && categoryId > 0) {
        removeLocally(categoryId);
      } else {
        unawaited(refreshSilently());
      }
      return;
    }

    final rawCategory = eventData['category'];
    if (rawCategory is Map) {
      final categoryMap = Map<String, dynamic>.from(rawCategory);
      final category = CategoryModel.fromJson(categoryMap);
      final currentUser = ref.read(authProvider).user;

      if (currentUser != null && currentUser.isCustomer) {
        final isActive =
            categoryMap['is_active'] == true || categoryMap['is_active'] == 1;
        final allowedIds =
            currentUser.customer?.allowedCategoryIds ?? const <int>[];
        if (!isActive || !allowedIds.contains(category.id)) {
          removeLocally(category.id);
          return;
        }
      }

      final current = state.valueOrNull;
      if (current == null) {
        unawaited(refreshSilently());
        return;
      }

      final exists = current.any((c) => c.id == category.id);
      if (exists) {
        updateLocally(category);
      } else {
        addLocally(category);
      }

      if (eventType == 'update') {
        ref
            .read(productsListProvider.notifier)
            .updateCategoryNameLocally(category.id, category.name);
      }
      return;
    }

    unawaited(refreshSilently());
  }

  bool _sameCategoryData(CategoryModel a, CategoryModel b) {
    return a.id == b.id && a.name == b.name && a.productsCount == b.productsCount;
  }

  Future<void> refreshSilently({bool rethrowOnError = false}) async {
    if (_disposed) return;
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.get(
        '/categories',
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
        ),
      );
      if (_disposed) return;
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is List) {
        final List data = response.data['data'] as List;
        final fresh = data.map((json) => CategoryModel.fromJson(json)).toList();
        final current = state.valueOrNull;
        if (current == null) {
          state = AsyncValue.data(fresh);
          return;
        }
        final currentById = {for (final c in current) c.id: c};
        final updated = fresh.map((item) {
          final existing = currentById[item.id];
          return existing != null && _sameCategoryData(existing, item)
              ? existing
              : item;
        }).toList();

        var hasChanges = current.length != updated.length;
        for (var i = 0; !hasChanges && i < current.length; i++) {
          hasChanges = !identical(current[i], updated[i]);
        }
        if (!hasChanges) return;

        state = AsyncValue.data(updated);
      }
    } catch (_) {
      if (rethrowOnError) rethrow;
      // Keep current categories on transient error
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh && !_disposed) {
        _pendingRefresh = false;
        unawaited(refreshSilently());
      }
    }
  }

  void addLocally(CategoryModel category) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final updated = [
      ...current.where((c) => c.id != category.id),
      category,
    ]..sort((a, b) => a.name.compareTo(b.name));
    state = AsyncValue.data(updated);
  }

  void updateLocally(CategoryModel category) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final updated = current
        .map((c) => c.id == category.id ? category : c)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    state = AsyncValue.data(updated);
  }

  void removeLocally(int id) {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncValue.data(current.where((c) => c.id != id).toList());
  }
}

final categoriesListProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
  CategoriesNotifier.new,
);

final categoryActionsProvider = Provider<CategoryActions>((ref) {
  final api = ref.watch(apiClientProvider);
  return CategoryActions(api, ref);
});

class CategoryActions {
  final ApiClient api;
  final Ref ref;

  CategoryActions(this.api, this.ref);

  Future<CategoryModel> addCategory(String name) async {
    try {
      final response = await api.client.post(
        '/categories',
        data: {'name': name.trim()},
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          api.extractErrorMessage(
            response.data,
            defaultMsg: 'نەتوانرا جۆری کاڵا زیاد بکرێت',
          ),
        );
      }
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw const FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed category response payload)',
        );
      }
      final category = CategoryModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      ref.read(categoriesListProvider.notifier).addLocally(category);
      return category;
    } on DioException catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<CategoryModel> updateCategory(int id, String name) async {
    try {
      final response = await api.client.put(
        '/categories/$id',
        data: {'name': name.trim()},
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          api.extractErrorMessage(
            response.data,
            defaultMsg: 'نەتوانرا ناوی جۆر نوێ بکرێتەوە',
          ),
        );
      }
      final resData = response.data;
      if (resData is! Map || resData['data'] is! Map) {
        throw const FormatException(
          'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed category response payload)',
        );
      }
      final updatedCategory = CategoryModel.fromJson(
        Map<String, dynamic>.from(resData['data']),
      );
      ref.read(categoriesListProvider.notifier).updateLocally(updatedCategory);
      ref
          .read(productsListProvider.notifier)
          .updateCategoryNameLocally(updatedCategory.id, updatedCategory.name);
      return updatedCategory;
    } on DioException catch (e) {
      throw Exception(api.parseError(e));
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final response = await api.client.delete('/categories/$id');
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          api.extractErrorMessage(
            response.data,
            defaultMsg: 'نەتوانرا جۆرەکە بسڕدرێتەوە',
          ),
        );
      }
      ref.read(categoriesListProvider.notifier).removeLocally(id);
    } on DioException catch (e) {
      throw Exception(api.parseError(e));
    }
  }
}
