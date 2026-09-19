import 'package:pos_app/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/models/user_model.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/models/route_model.dart';
import '../../../shared/providers/customer_provider.dart';
import '../../../shared/providers/route_provider.dart';
import '../../../shared/providers/warehouse_provider.dart';
import '../providers/user_provider.dart';
import '../providers/reports_provider.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  int? _selectedCustomerId;
  int? _selectedSalesmanId;
  int? _selectedRouteId;
  int? _selectedWarehouseId;
  String? _selectedStatus = 'DELIVERED';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterExpanded = false;

  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    // Default to this month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _selectedStatus = 'DELIVERED';
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedCustomerId != null)
          'customer_id': _selectedCustomerId.toString(),
        if (_selectedSalesmanId != null)
          'salesman_id': _selectedSalesmanId.toString(),
        if (_selectedRouteId != null) 'route_id': _selectedRouteId.toString(),
        if (_selectedWarehouseId != null)
          'warehouse_id': _selectedWarehouseId.toString(),
        if (_selectedStatus != null && _selectedStatus != 'ALL')
          'status': _selectedStatus,
        if (_startDate != null)
          'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null)
          'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCustomerId = null;
      _selectedSalesmanId = null;
      _selectedRouteId = null;
      _selectedWarehouseId = null;
      _selectedStatus = 'DELIVERED';
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
      _filters = {
        'status': 'DELIVERED',
        'start_date': _startDate!.toIso8601String().split('T').first,
        'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  String _formatCurrency(num amount) {
    return Formatters.currency(amount);
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(salesReportProvider(_filters));
    final customersAsync = ref.watch(customerListProvider);
    final salesmenAsync = ref.watch(salesmenListProvider);
    final routesAsync = ref.watch(routeListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرتی فرۆشتن', style: AppTextStyles.h2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                final isNarrow = constraints.maxWidth < 360;

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isFilterExpanded = !_isFilterExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tune,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'فلتەرکردنی ڕاپۆرت',
                                  style: AppTextStyles.h3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_isFilterExpanded && _selectedStatus != null && _selectedStatus != 'ALL') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _selectedStatus == 'DELIVERED'
                                        ? 'گەیەنراوە'
                                        : (_selectedStatus ?? ''),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              TextButton(
                                onPressed: _clearFilters,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'پاککردنەوە',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _isFilterExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_isFilterExpanded) ...[
                        const SizedBox(height: AppSpacing.xs),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isFilterExpanded = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              border: Border.all(
                                color: AppColors.borderLight.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_startDate?.toIso8601String().split('T').first ?? ''}  بۆ  ${_endDate?.toIso8601String().split('T').first ?? ''}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'دەستکاریکردنی فلتەر',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                        if (isMobile) ...[
                          Row(
                            children: [
                              Expanded(child: _buildStartDatePicker(context)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: _buildEndDatePicker(context)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSalesmanDropdown(salesmenAsync),
                          const SizedBox(height: AppSpacing.sm),
                          _buildCustomerDropdown(customersAsync),
                          const SizedBox(height: AppSpacing.sm),
                          if (isNarrow) ...[
                            _buildRouteDropdown(routesAsync),
                            const SizedBox(height: AppSpacing.sm),
                            _buildWarehouseDropdown(warehousesAsync),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildRouteDropdown(routesAsync),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _buildWarehouseDropdown(
                                    warehousesAsync,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildStatusDropdown(),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: _buildStartDatePicker(context)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildEndDatePicker(context)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildSalesmanDropdown(salesmenAsync),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildCustomerDropdown(customersAsync),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: _buildRouteDropdown(routesAsync)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildWarehouseDropdown(warehousesAsync),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildStatusDropdown()),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: 'جێبەجێکردنی فلتەر',
                            icon: Icons.check,
                            onPressed: () {
                              _applyFilters();
                              setState(() {
                                _isFilterExpanded = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Report Results
            reportAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: ErrorState(
                  title: 'هەڵەیەک ڕوویدا',
                  message: Formatters.cleanError(err),
                  retryText: 'دووبارە هەوڵبدەرەوە',
                  onRetry: () =>
                      ref.invalidate(salesReportProvider(_filters)),
                ),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards
                  _buildSummaryCards(data.summary),
                  const SizedBox(height: AppSpacing.md),

                  // Salesman Breakdown
                  if (data.bySalesman.isNotEmpty) ...[
                    const Text('فرۆشتن بەپێی مەندوب', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSalesmanBreakdownTable(data.bySalesman),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Orders Table
                  const Text('لیستی پسوڵەکانی فرۆشتن', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _buildOrdersTable(data.orders),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(dynamic summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final spacing = isMobile ? AppSpacing.sm : AppSpacing.md;
        final cardWidth = isMobile
            ? (constraints.maxWidth - spacing) / 2
            : (constraints.maxWidth - 3 * spacing) / 4;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildKpiCard(
              'کۆی فرۆشتنی پاکت',
              _formatCurrency(summary.totalNetSales),
              AppColors.primary,
              cardWidth,
            ),
            _buildKpiCard(
              'کۆی قازانج',
              _formatCurrency(summary.totalProfitAmount),
              AppColors.success,
              cardWidth,
            ),
            _buildKpiCard(
              'ژمارەی پسوڵەکان',
              '${summary.totalOrdersCount} پسوڵە',
              AppColors.purple,
              cardWidth,
            ),
            _buildKpiCard(
              'تێکڕای پسوڵە',
              _formatCurrency(summary.averageOrderValue),
              AppColors.info,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, double width) {
    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppTextStyles.h3.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmanBreakdownTable(List<dynamic> breakdowns) {
    return AppCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTextStyles.bodyBold,
          dataTextStyle: AppTextStyles.bodyMedium,
          columns: const [
            DataColumn(label: Text('مەندوب')),
            DataColumn(label: Text('ژمارەی پسوڵە')),
            DataColumn(label: Text('کۆی فرۆشتن')),
            DataColumn(label: Text('کۆی قازانج')),
          ],
          rows: breakdowns.map((b) {
            return DataRow(
              cells: [
                DataCell(Text(b.salesmanName)),
                DataCell(Text('${b.ordersCount}')),
                DataCell(
                  Text(
                    _formatCurrency(b.totalSales),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(b.totalProfit),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersTable(List<dynamic> orders) {
    if (orders.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'هیچ پسوڵەیەک نەدۆزرایەوە بەپێی ئەم فلتەرە',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTextStyles.bodyBold,
          dataTextStyle: AppTextStyles.bodyMedium,
          columns: const [
            DataColumn(label: Text('ژ. پسوڵە')),
            DataColumn(label: Text('بەروار')),
            DataColumn(label: Text('کڕیار')),
            DataColumn(label: Text('ڕێگا')),
            DataColumn(label: Text('مەندوب')),
            DataColumn(label: Text('دۆخ')),
            DataColumn(label: Text('بڕی گشتی')),
            DataColumn(label: Text('داشکاندن')),
            DataColumn(label: Text('بڕی کۆتایی')),
            DataColumn(label: Text('قازانج')),
          ],
          rows: orders.map((o) {
            Color statusColor = AppColors.primary;
            String statusLabel = o.status;
            if (o.status == 'DELIVERED') {
              statusColor = AppColors.success;
              statusLabel = 'گەیەندراوە';
            } else if (o.status == 'CONFIRMED') {
              statusColor = AppColors.info;
              statusLabel = 'پەسەندکراوە';
            } else if (o.status == 'CANCELLED') {
              statusColor = AppColors.danger;
              statusLabel = 'هەڵوەشاوە';
            }

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    o.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(o.orderDate.split('T').first)),
                DataCell(Text(o.customerName)),
                DataCell(Text(o.routeName)),
                DataCell(Text(o.salesmanName)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(o.subtotal),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(o.discountAmount),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(o.totalAmount),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    _formatCurrency(o.totalProfit),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStartDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, true),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'لە بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        child: Text(
          _startDate != null
              ? _startDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, false),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'تا بەرواری',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        child: Text(
          _endDate != null
              ? _endDate!.toIso8601String().split('T').first
              : 'دیارینەکراوە',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSalesmanDropdown(AsyncValue<List<UserModel>> salesmenAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedSalesmanId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'مەندوب',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت مەندوبەکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final s in salesmenAsync.valueOrNull ?? <UserModel>[])
          DropdownMenuItem<int?>(
            value: s.id,
            child: Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedSalesmanId = val),
    );
  }

  Widget _buildCustomerDropdown(AsyncValue<List<Customer>> customersAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedCustomerId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'کڕیار',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت کڕیارەکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final c in customersAsync.valueOrNull ?? <Customer>[])
          DropdownMenuItem<int?>(
            value: c.id,
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedCustomerId = val),
    );
  }

  Widget _buildRouteDropdown(AsyncValue<List<RouteModel>> routesAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedRouteId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'ڕێگا (هێڵ)',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت ڕێگاکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final r in routesAsync.valueOrNull ?? <RouteModel>[])
          DropdownMenuItem<int?>(
            value: r.id,
            child: Text(
              r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedRouteId = val),
    );
  }

  Widget _buildWarehouseDropdown(
    AsyncValue<List<WarehouseModel>> warehousesAsync,
  ) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedWarehouseId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'کۆگا',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'گشت کۆگاکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final w in warehousesAsync.valueOrNull ?? <WarehouseModel>[])
          DropdownMenuItem<int?>(
            value: w.id,
            child: Text(
              w.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (val) => setState(() => _selectedWarehouseId = val),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedStatus,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'دۆخی پسوڵە',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
          value: 'ALL',
          child: Text('گشتی', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'DELIVERED',
          child: Text('گەیەندراوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'CONFIRMED',
          child: Text('پەسەندکراوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'IN_DELIVERY',
          child: Text('لە گەیاندندایە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'PACKING',
          child: Text('لە پێچانەوەدایە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'CANCELLED',
          child: Text('هەڵوەشاوەتەوە', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (val) => setState(() => _selectedStatus = val),
    );
  }
}
