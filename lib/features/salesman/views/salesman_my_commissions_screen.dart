import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/api_client.dart';
import '../../../../core/sync/pusher_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/models/commission_model.dart';
import '../../admin/views/providers/commission_provider.dart';

final myCommissionsProvider =
    FutureProvider.family<List<CommissionModel>, String?>((
      ref,
      status,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/commissions/my-commissions',
          queryParameters: {
            if (status != null && status != 'ALL') 'status': status,
          },
        );
        if (response.statusCode == 200) {
          final resData = response.data['data'];
          final List items;
          if (resData is Map && resData['data'] is List) {
            items = resData['data'];
          } else if (resData is List) {
            items = resData;
          } else {
            throw const FormatException(
              'داتای وەڵامدانەوەی سێرڤەر نادروستە (Malformed my-commissions response payload)',
            );
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

final myCommissionSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.client.get('/commissions/summary');
    if (response.statusCode == 200) {
      final resData = response.data['data'] ?? response.data;
      if (resData is Map<String, dynamic>) {
        return resData;
      } else if (resData is Map) {
        return Map<String, dynamic>.from(resData);
      }
    }
    return {};
  } catch (e) {
    return {};
  }
});

class SalesmanMyCommissionsScreen extends ConsumerStatefulWidget {
  const SalesmanMyCommissionsScreen({super.key});

  @override
  ConsumerState<SalesmanMyCommissionsScreen> createState() =>
      _SalesmanMyCommissionsScreenState();
}

class _SalesmanMyCommissionsScreenState
    extends ConsumerState<SalesmanMyCommissionsScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _setupPusherListener();
  }

  void _setupPusherListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pusher = ref.read(pusherServiceProvider);
      final user = ref.read(authProvider).user;
      
      pusher.subscribeToChannel('commissions', _onCommissionPusherEvent);
      if (user != null) {
        pusher.subscribeToChannel('private-user-notifications.${user.id}', _onCommissionPusherEvent);
      }
    });
  }

  void _onCommissionPusherEvent(Map<String, dynamic> data) {
    ref.invalidate(myCommissionsProvider);
    ref.invalidate(myCommissionSummaryProvider);
  }

  @override
  void dispose() {
    final pusher = ref.read(pusherServiceProvider);
    final user = ref.read(authProvider).user;
    pusher.unsubscribeFromChannel('commissions', _onCommissionPusherEvent);
    if (user != null) {
      pusher.unsubscribeFromChannel('private-user-notifications.${user.id}', _onCommissionPusherEvent);
    }
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        label = 'پەسەندکراو';
        break;
      case 'paid':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        label = 'دراوە';
        break;
      case 'cancelled':
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        label = 'هەڵوەشێنراوە';
        break;
      case 'calculated':
      default:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        label = 'هەژمارکراو';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, CommissionModel commission) {
    final isPaid = commission.status.toLowerCase() == 'paid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'وردەکاری کۆمسیۆنی #${commission.id}',
                        style: AppTextStyles.h2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(commission.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ماوە: ${commission.periodFrom} تا ${commission.periodTo}',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: AppSpacing.md),

                // Paid Banner if paid
                if (isPaid) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: AppColors.success, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'پارەی ئەم کۆمسیۆنە بە سەرکەوتوویی دراوە',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'بڕی دراو: ${_formatCurrency(commission.commissionAmount)} | بەروار: ${commission.paidAt != null ? commission.paidAt!.split("T").first : 'نادیار'} (${commission.paymentMethod ?? 'کاش'})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Financial Breakdown Card
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'کۆی فرۆشتن (پسوڵە گەیەنراوەکان):',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCurrency(commission.totalSales),
                            style: AppTextStyles.bodyBold,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'کۆی قازانجی بەدەستهاتوو:',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCurrency(commission.totalProfit),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'ڕێژەی کۆمسیۆن:',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${commission.commissionRate}%',
                            style: AppTextStyles.bodyBold,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      if (commission.fixedAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'مووچە / بڕی سابت:',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatCurrency(commission.fixedAmount),
                              style: AppTextStyles.bodyBold,
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isPaid ? 'بڕی کۆمسیۆنی دراو:' : 'بڕی کۆمسیۆنی شایستە:',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCurrency(commission.commissionAmount),
                            style: TextStyle(
                              color: isPaid ? AppColors.success : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      if (commission.notes != null && commission.notes!.isNotEmpty) ...[
                        const Divider(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'تێبینی: ${commission.notes}',
                            style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Delivered Orders Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'پسوڵە گەیەنراوە شایستەکان (${commission.details.length})',
                        style: AppTextStyles.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'تەنها گەیەنراوەکان هەژمارکراون',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (commission.details.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text('هیچ پسوڵەیەک تۆمار نەکراوە'),
                  )
                else
                  ...commission.details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          d.orderNumber ?? 'پسوڵەی #${d.salesOrderId}',
                                          style: AppTextStyles.bodyBold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    d.customerName ?? 'کڕیار',
                                    style: AppTextStyles.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'فرۆش: ${_formatCurrency(d.salesAmount)}',
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(d.commissionAmount),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'قازانج: ${_formatCurrency(d.profitAmount)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commissionsAsync = ref.watch(myCommissionsProvider(_selectedStatus));
    final summaryAsync = ref.watch(myCommissionSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کۆمسیۆنەکانم', style: AppTextStyles.h2),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myCommissionsProvider);
          ref.invalidate(myCommissionSummaryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary KPI Cards for Salesman
              summaryAsync.when(
                data: (summary) {
                  final paid = summary['paid'] as Map<String, dynamic>? ?? {};
                  final calculated = summary['calculated'] as Map<String, dynamic>? ?? {};
                  final approved = summary['approved'] as Map<String, dynamic>? ?? {};
                  
                  final paidAmount = (paid['amount'] as num?)?.toInt() ?? 0;
                  final pendingAmount = ((calculated['amount'] as num?)?.toInt() ?? 0) +
                      ((approved['amount'] as num?)?.toInt() ?? 0);
                  final paidCount = (paid['count'] as num?)?.toInt() ?? 0;

                  return Row(
                    children: [
                      // Paid Commissions Card (Prominently Highlighted)
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'کۆمسیۆنی دراو',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatCurrency(paidAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$paidCount کۆمسیۆنی دراو',
                                style: AppTextStyles.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Pending / Calculated Commissions Card
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'چاوەڕوانکراو',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.hourglass_top, color: AppColors.warning, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatCurrency(pendingAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'هەژمارکراو / پەسەندکراو',
                                style: AppTextStyles.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('هەمووی'),
                      selected:
                          _selectedStatus == null || _selectedStatus == 'ALL',
                      onSelected: (selected) =>
                          setState(() => _selectedStatus = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('دراوە'),
                        ],
                      ),
                      selected: _selectedStatus == 'paid',
                      onSelected: (selected) => setState(
                        () => _selectedStatus = selected ? 'paid' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('پەسەندکراو'),
                      selected: _selectedStatus == 'approved',
                      onSelected: (selected) => setState(
                        () => _selectedStatus = selected ? 'approved' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('هەژمارکراو'),
                      selected: _selectedStatus == 'calculated',
                      onSelected: (selected) => setState(
                        () => _selectedStatus = selected ? 'calculated' : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // List of Commissions
              commissionsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: ErrorState(
                      title: 'هەڵەیەک ڕوویدا',
                      message: Formatters.cleanError(e),
                      retryText: 'دووبارە هەوڵبدەرەوە',
                      onRetry: () {
                        ref.invalidate(myCommissionsProvider);
                        ref.invalidate(myCommissionSummaryProvider);
                      },
                    ),
                  ),
                ),
                data: (commissions) {
                  if (commissions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'هیچ تۆمارێکی کۆمسیۆن نەدۆزرایەوە',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'کۆمسیۆن تەنها لەسەر ئەو پسوڵانە هەژمار دەکرێت کە بە تەواوی گەیەنراون.',
                            style: AppTextStyles.caption.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: commissions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final c = commissions[index];
                      final isPaid = c.status.toLowerCase() == 'paid';

                      return AppCard(
                        onTap: () => _showDetailsModal(context, c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'کۆمسیۆنی #${c.id}',
                                  style: AppTextStyles.bodyBold,
                                ),
                                _buildStatusChip(c.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ماوە: ${c.periodFrom} تا ${c.periodTo}',
                              style: AppTextStyles.caption,
                            ),
                            if (isPaid && c.paidAt != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check, size: 14, color: AppColors.success),
                                    const SizedBox(width: 4),
                                    Text(
                                      'دراوە لە: ${c.paidAt!.split("T").first} (${c.paymentMethod ?? 'کاش'})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'فرۆش: ${_formatCurrency(c.totalSales)}',
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      'قازانج: ${_formatCurrency(c.totalProfit)} (${c.commissionRate}%)',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatCurrency(c.commissionAmount),
                                      style: TextStyle(
                                        color: isPaid ? AppColors.success : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                    Text(
                                      isPaid ? 'دراوە' : 'شایستە',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isPaid ? AppColors.success : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
