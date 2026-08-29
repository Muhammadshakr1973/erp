import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/customer_provider.dart';
import '../../../shared/providers/route_provider.dart';
import '../../../shared/providers/warehouse_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/reports_provider.dart';

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
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    // Default to this month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedCustomerId != null) 'customer_id': _selectedCustomerId.toString(),
        if (_selectedSalesmanId != null) 'salesman_id': _selectedSalesmanId.toString(),
        if (_selectedRouteId != null) 'route_id': _selectedRouteId.toString(),
        if (_selectedWarehouseId != null) 'warehouse_id': _selectedWarehouseId.toString(),
        if (_selectedStatus != null && _selectedStatus != 'ALL') 'status': _selectedStatus,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCustomerId = null;
      _selectedSalesmanId = null;
      _selectedRouteId = null;
      _selectedWarehouseId = null;
      _selectedStatus = null;
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
      _filters = {
        'start_date': _startDate!.toIso8601String().split('T').first,
        'end_date': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('فلتەرکردنی ڕاپۆرت', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 700;
                      if (isMobile) {
                        return Column(
                          children: [
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
                            Row(
                              children: [
                                Expanded(child: _buildRouteDropdown(routesAsync)),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: _buildWarehouseDropdown(warehousesAsync)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildStatusDropdown(),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(text: 'جێبەجێکردنی فلتەر', onPressed: _applyFilters),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildStartDatePicker(context)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildEndDatePicker(context)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildSalesmanDropdown(salesmenAsync)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildCustomerDropdown(customersAsync)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: _buildRouteDropdown(routesAsync)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildWarehouseDropdown(warehousesAsync)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildStatusDropdown()),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppButton(text: 'جێبەجێکردن', onPressed: _applyFilters),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
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
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('هەڵەیەک ڕوویدا: $err', style: const TextStyle(color: AppColors.danger)),
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

  Widget _buildSummaryCards(summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile ? (constraints.maxWidth - AppSpacing.sm) / 2 : (constraints.maxWidth - 3 * AppSpacing.md) / 4;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildKpiCard('کۆی فرۆشتنی پاکت', _formatCurrency(summary.totalNetSales), AppColors.primary, cardWidth),
            _buildKpiCard('کۆی قازانج', _formatCurrency(summary.totalProfitAmount), AppColors.success, cardWidth),
            _buildKpiCard('ژمارەی پسوڵەکان', '${summary.totalOrdersCount} پسوڵە', AppColors.purple, cardWidth),
            _buildKpiCard('تێکڕای پسوڵە', _formatCurrency(summary.averageOrderValue), AppColors.info, cardWidth),
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
            Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(color: color, fontWeight: FontWeight.bold),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesmanBreakdownTable(List breakdowns) {
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
            return DataRow(cells: [
              DataCell(Text(b.salesmanName)),
              DataCell(Text('${b.ordersCount}')),
              DataCell(Text(_formatCurrency(b.totalSales), textDirection: TextDirection.ltr)),
              DataCell(Text(_formatCurrency(b.totalProfit), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersTable(List orders) {
    if (orders.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('هیچ پسوڵەیەک نەدۆزرایەوە بەپێی ئەم فلتەرە', style: AppTextStyles.bodyMedium),
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

            return DataRow(cells: [
              DataCell(Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(o.orderDate.split('T').first)),
              DataCell(Text(o.customerName)),
              DataCell(Text(o.routeName)),
              DataCell(Text(o.salesmanName)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              DataCell(Text(_formatCurrency(o.subtotal), textDirection: TextDirection.ltr)),
              DataCell(Text(_formatCurrency(o.discountAmount), textDirection: TextDirection.ltr)),
              DataCell(Text(_formatCurrency(o.totalAmount), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_formatCurrency(o.totalProfit), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
            ]);
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(_startDate != null ? _startDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(_endDate != null ? _endDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
      ),
    );
  }

  Widget _buildSalesmanDropdown(AsyncValue salesmenAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedSalesmanId,
      decoration: const InputDecoration(
        labelText: 'مەندوب',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت مەندوبەکان')),
        ...salesmenAsync.when(
          data: (list) => list.map<DropdownMenuItem<int?>>((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedSalesmanId = val),
    );
  }

  Widget _buildCustomerDropdown(AsyncValue customersAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedCustomerId,
      decoration: const InputDecoration(
        labelText: 'کڕیار',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت کڕیارەکان')),
        ...customersAsync.when(
          data: (list) => list.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedCustomerId = val),
    );
  }

  Widget _buildRouteDropdown(AsyncValue routesAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedRouteId,
      decoration: const InputDecoration(
        labelText: 'ڕێگا (هێڵ)',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت ڕێگاکان')),
        ...routesAsync.when(
          data: (list) => list.map<DropdownMenuItem<int?>>((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedRouteId = val),
    );
  }

  Widget _buildWarehouseDropdown(AsyncValue warehousesAsync) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedWarehouseId,
      decoration: const InputDecoration(
        labelText: 'کۆگا',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('گشت کۆگاکان')),
        ...warehousesAsync.when(
          data: (list) => list.map<DropdownMenuItem<int?>>((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
          loading: () => [],
          error: (_, _) => [],
        ),
      ],
      onChanged: (val) => setState(() => _selectedWarehouseId = val),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedStatus,
      decoration: const InputDecoration(
        labelText: 'دۆخی پسوڵە',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('گشتی')),
        DropdownMenuItem(value: 'DELIVERED', child: Text('گەیەندراوە')),
        DropdownMenuItem(value: 'CONFIRMED', child: Text('پەسەندکراوە')),
        DropdownMenuItem(value: 'IN_DELIVERY', child: Text('لە گەیاندندایە')),
        DropdownMenuItem(value: 'PACKING', child: Text('لە پێچانەوەدایە')),
        DropdownMenuItem(value: 'CANCELLED', child: Text('هەڵوەشاوەتەوە')),
      ],
      onChanged: (val) => setState(() => _selectedStatus = val),
    );
  }
}
