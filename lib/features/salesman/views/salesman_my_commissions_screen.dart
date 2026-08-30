import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/api_client.dart';
import '../../shared/models/commission_model.dart';
import '../../admin/views/providers/commission_provider.dart';

final myCommissionsProvider =
    FutureProvider.family<List<CommissionModel>, Map<String, dynamic>>((
      ref,
      filters,
    ) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.client.get(
          '/commissions/my-commissions',
          queryParameters: filters,
        );
        if (response.statusCode == 200) {
          final resData = response.data['data'];
          final List items = (resData is Map && resData.containsKey('data'))
              ? resData['data']
              : (resData is List ? resData : []);
          return items
              .map(
                (json) =>
                    CommissionModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
        return [];
      } catch (e) {
        throw Exception(api.parseError(e));
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

  String _formatCurrency(num amount) {
    return '${Formatters.currency(amount)}';
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = AppColors.info.withOpacity(0.15);
        fg = AppColors.info;
        label = 'پەسەندکراو';
        break;
      case 'paid':
        bg = AppColors.success.withOpacity(0.15);
        fg = AppColors.success;
        label = 'دراوە';
        break;
      case 'cancelled':
        bg = AppColors.danger.withOpacity(0.15);
        fg = AppColors.danger;
        label = 'هەڵوەشێنراوە';
        break;
      case 'calculated':
      default:
        bg = AppColors.warning.withOpacity(0.15);
        fg = AppColors.warning;
        label = 'هەژمارکراو';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'وردەکاری کۆمسیۆنی #${commission.id}',
                    style: AppTextStyles.h3,
                  ),
                  _buildStatusChip(commission.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ماوە: ${commission.periodFrom} تا ${commission.periodTo}',
                style: AppTextStyles.bodyMedium,
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('کۆی فرۆشتن:'),
                  Text(
                    _formatCurrency(commission.totalSales),
                    style: AppTextStyles.bodyBold,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('کۆی قازانج:'),
                  Text(
                    _formatCurrency(commission.totalProfit),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ڕێژەی کۆمسیۆن:'),
                  Text(
                    '${commission.commissionRate}%',
                    style: AppTextStyles.bodyBold,
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('بڕی کۆمسیۆنی شایستە:', style: AppTextStyles.h3),
                  Text(
                    _formatCurrency(commission.commissionAmount),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (commission.paidAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'بەرواری وەرگرتن: ${commission.paidAt!.split("T").first} (${commission.paymentMethod ?? 'کاش'})',
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Text('پسوڵە شایستەکان:', style: AppTextStyles.bodyBold),
              const SizedBox(height: AppSpacing.sm),
              if (commission.details.isEmpty)
                const Text('وردەکاری پسوڵەکان بەردەست نییە')
              else
                ...commission.details.map(
                  (d) => AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.orderNumber ?? 'پسوڵەی #${d.salesOrderId}',
                              style: AppTextStyles.bodyBold,
                            ),
                            Text(
                              d.customerName ?? 'کڕیار',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(d.commissionAmount),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'قازانج: ${_formatCurrency(d.profitAmount)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = {
      if (_selectedStatus != null && _selectedStatus != 'ALL')
        'status': _selectedStatus,
    };
    final commissionsAsync = ref.watch(myCommissionsProvider(filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text('کۆمسیۆنەکانم', style: AppTextStyles.h2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('گشتی'),
                    selected:
                        _selectedStatus == null || _selectedStatus == 'ALL',
                    onSelected: (selected) =>
                        setState(() => _selectedStatus = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('هەژمارکراو'),
                    selected: _selectedStatus == 'calculated',
                    onSelected: (selected) => setState(
                      () => _selectedStatus = selected ? 'calculated' : null,
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
                    label: const Text('دراوە'),
                    selected: _selectedStatus == 'paid',
                    onSelected: (selected) => setState(
                      () => _selectedStatus = selected ? 'paid' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: commissionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('هەڵەیەک ڕوویدا: $e')),
                data: (commissions) {
                  if (commissions.isEmpty) {
                    return const Center(
                      child: Text(
                        'هیچ تۆمارێکی کۆمسیۆن نەدۆزرایەوە',
                        style: AppTextStyles.h3,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: commissions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final c = commissions[index];
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
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'قازانج: ${_formatCurrency(c.totalProfit)}',
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      'ڕێژە: ${c.commissionRate}%',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatCurrency(c.commissionAmount),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textDirection: TextDirection.ltr,
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
            ),
          ],
        ),
      ),
    );
  }
}
