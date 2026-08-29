import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api_client.dart';
import '../providers/customer_provider.dart';
import '../providers/route_provider.dart';
import '../models/customer.dart';
import '../views/customer_form_dialog.dart';
import '../../admin/views/providers/reports_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/models/order_model.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  String? _ledgerEntryType;
  DateTime? _ledgerStartDate;
  DateTime? _ledgerEndDate;
  Map<String, dynamic> _ledgerFilters = {};

  final _paymentFormKey = GlobalKey<FormState>();
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  bool _isPaying = false;
  LatLng? _driverLocation;
  bool _isLocatingDriver = false;

  @override
  void initState() {
    super.initState();
    _ledgerFilters = {'customer_id': widget.customerId};
  }

  Future<void> _fetchDriverLocation() async {
    setState(() {
      _isLocatingDriver = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'نەتوانرا شوێنی ئێستات دیاری بکرێت: $e',
              style: const TextStyle(fontFamily: 'Rudaw'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocatingDriver = false;
        });
      }
    }
  }

  void _applyLedgerFilters() {
    setState(() {
      _ledgerFilters = {
        'customer_id': widget.customerId,
        if (_ledgerEntryType != null && _ledgerEntryType != 'ALL')
          'entry_type': _ledgerEntryType,
        if (_ledgerStartDate != null)
          'start_date': _ledgerStartDate!.toIso8601String().split('T').first,
        if (_ledgerEndDate != null)
          'end_date': _ledgerEndDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearLedgerFilters() {
    setState(() {
      _ledgerEntryType = null;
      _ledgerStartDate = null;
      _ledgerEndDate = null;
      _ledgerFilters = {'customer_id': widget.customerId};
    });
  }

  Future<void> _selectLedgerDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _ledgerStartDate = picked;
        } else {
          _ledgerEndDate = picked;
        }
      });
    }
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  void _showQrCodeDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            customer.name,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: 'CUST-${customer.id}',
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'سکان بکە بۆ دۆزینەوەی خێرای کڕیار',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('داخستن'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    Customer customer,
  ) async {
    _paymentAmountController.clear();
    _paymentNotesController.clear();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تۆمارکردنی پارەدان', style: AppTextStyles.h2),
            content: Form(
              key: _paymentFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: _paymentAmountController,
                    labelText: 'بڕی پارە (د.ع)',
                    prefixIcon: Icons.money,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty)
                        return 'تکایە بڕی پارە بنووسە';
                      if (int.tryParse(val) == null) return 'بڕی پارە نادروستە';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _paymentNotesController,
                    labelText: 'تێبینی',
                    prefixIcon: Icons.note,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'پاشگەزبوونەوە',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              AppButton(
                text: 'تۆمارکردن',
                isLoading: _isPaying,
                onPressed: () async {
                  if (_paymentFormKey.currentState!.validate()) {
                    setStateDialog(() => _isPaying = true);
                    try {
                      final api = ref.read(apiClientProvider);
                      final response = await api.client.post(
                        '/payments',
                        data: {
                          'customer_id': customer.id,
                          'amount': int.parse(_paymentAmountController.text),
                          'notes': _paymentNotesController.text,
                          'payment_method': 'CASH',
                        },
                      );

                      if (response.statusCode == 201) {
                        ref.invalidate(singleCustomerProvider(customer.id));
                        ref.invalidate(
                          customerDebtsReportProvider(_ledgerFilters),
                        );
                        ref.invalidate(customerListProvider);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'پارەدانەکە بەسەرکەوتوویی تۆمارکرا',
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('هەڵە ڕوویدا: $e'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    } finally {
                      setStateDialog(() => _isPaying = false);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerIdInt = int.tryParse(widget.customerId) ?? 0;
    final customerAsync = ref.watch(singleCustomerProvider(customerIdInt));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('زانیاری کڕیار', style: AppTextStyles.h2),
          actions: [
            customerAsync.maybeWhen(
              data: (customer) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'دەستکاریکردنی کڕیار',
                    onPressed: () {
                      showDialog<bool>(
                        context: context,
                        builder: (context) =>
                            CustomerFormDialog(customer: customer),
                      ).then((success) {
                        if (success == true) {
                          ref.invalidate(singleCustomerProvider(customer.id));
                          ref.invalidate(customerListProvider);
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    tooltip: 'سڕینەوەی کڕیار',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'سڕینەوەی کڕیار',
                            style: AppTextStyles.h3,
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'دڵنیایت لە سڕینەوەی کڕیاری "${customer.name}"؟',
                              ),
                              if (customer.balance > 0) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: AppColors.danger,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'ئاگاداربە: ئەم کڕیارە بڕی ${customer.balance.toInt()} د.ع قەرزی لەسەرە!',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('پاشگەزبوونەوە'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await ref
                                      .read(customerActionsProvider)
                                      .deleteCustomer(customer.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'کڕیار بە سەرکەوتوویی سڕایەوە',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('هەڵە لە سڕینەوە: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('سڕینەوە'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'زانیاری'),
              Tab(text: 'قەرز (Ledger)'),
              Tab(text: 'پسوڵەکان'),
            ],
            labelStyle: AppTextStyles.bodyBold,
          ),
        ),
        body: customerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('هەڵە ڕوویدا: $e')),
          data: (customer) => TabBarView(
            children: [
              _buildInfoTab(context, customer),
              _buildLedgerTab(context, customer),
              _buildOrdersTab(context, customer),
            ],
          ),
        ),
        floatingActionButton: customerAsync.maybeWhen(
          data: (customer) => FloatingActionButton.extended(
            onPressed: () => _showPaymentDialog(context, customer),
            icon: const Icon(Icons.payment),
            label: const Text('پارەدان'),
            backgroundColor: AppColors.primary,
          ),
          orElse: () => null,
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context, Customer customer) {
    final theme = Theme.of(context);
    final routesAsync = ref.watch(routeListProvider);
    String routeName = 'بێ گەڕەک / ڕاوت';
    routesAsync.whenData((routes) {
      for (final r in routes) {
        if (r.id == customer.routeId) {
          routeName = r.name;
          break;
        }
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                AppIcons.customer,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(customer.name, style: AppTextStyles.displayMedium),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.blueGrey),
                  tooltip: 'پیشاندانی QR',
                  onPressed: () => _showQrCodeDialog(context, customer),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppCard(
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  Icons.phone,
                  customer.phone ?? 'بێ ژمارە',
                ),
                const Divider(),
                _buildInfoRow(
                  context,
                  Icons.location_on,
                  customer.address ?? 'بێ ناونیشان',
                ),
                const Divider(),
                _buildInfoRow(context, Icons.alt_route, routeName),
                if (customer.latitude != null &&
                    customer.longitude != null) ...[
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'شوێنی کڕیار لەسەر نەخشە',
                        style: AppTextStyles.bodyBold,
                      ),
                      TextButton.icon(
                        onPressed: _isLocatingDriver
                            ? null
                            : _fetchDriverLocation,
                        icon: _isLocatingDriver
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: const Text(
                          'شوێنی من',
                          style: TextStyle(fontFamily: 'Rudaw'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            customer.latitude!,
                            customer.longitude!,
                          ),
                          initialZoom: 13.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.gardipos.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  customer.latitude!,
                                  customer.longitude!,
                                ),
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              ),
                              if (_driverLocation != null)
                                Marker(
                                  point: _driverLocation!,
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('کۆی قەرزی ئێستا', style: AppTextStyles.bodyLarge),
                Text(
                  _formatCurrency(customer.balance),
                  style: AppTextStyles.priceLarge.copyWith(
                    color: customer.balance > 0
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context, Customer customer) {
    final ledgerAsync = ref.watch(customerDebtsReportProvider(_ledgerFilters));

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // Filter UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _ledgerEntryType,
                        decoration: const InputDecoration(
                          labelText: 'جۆری جوڵە',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('گشتی')),
                          DropdownMenuItem(
                            value: 'PAYMENT',
                            child: Text('پارەدان'),
                          ),
                          DropdownMenuItem(
                            value: 'SALE',
                            child: Text('فرۆشتن'),
                          ),
                          DropdownMenuItem(
                            value: 'RETURN',
                            child: Text('گەڕانەوە'),
                          ),
                          DropdownMenuItem(
                            value: 'ADJUSTMENT',
                            child: Text('ڕاستکردنەوە'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _ledgerEntryType = val),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectLedgerDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'لە بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            _ledgerStartDate != null
                                ? _ledgerStartDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first
                                : 'دیارینەکراوە',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectLedgerDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تا بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            _ledgerEndDate != null
                                ? _ledgerEndDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first
                                : 'دیارینەکراوە',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _clearLedgerFilters,
                      child: const Text(
                        'پاککردنەوە',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: AppButton(
                        text: 'فلتەر',
                        onPressed: _applyLedgerFilters,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ledgerAsync.when(
            data: (ledgerList) {
              if (ledgerList.isEmpty) {
                return const Center(child: Text('هیچ مێژوویەک نییە'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: ledgerList.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = ledgerList[index];
                  final isCredit = entry.type == 'credit';
                  final amountColor = isCredit
                      ? AppColors.success
                      : AppColors.danger;

                  String entryTypeLabel = entry.entryType;
                  if (entryTypeLabel == 'PAYMENT') entryTypeLabel = 'پارەدان';
                  if (entryTypeLabel == 'SALE') entryTypeLabel = 'فرۆشتن';
                  if (entryTypeLabel == 'RETURN') entryTypeLabel = 'گەڕانەوە';
                  if (entryTypeLabel == 'ADJUSTMENT')
                    entryTypeLabel = 'ڕاستکردنەوە/قەرزی سەرەتا';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.description ?? entryTypeLabel,
                      style: AppTextStyles.bodyBold,
                    ),
                    subtitle: Text(
                      '${entry.createdAt?.split('T').first ?? ''} • $entryTypeLabel',
                      style: AppTextStyles.caption,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}${_formatCurrency(entry.amount)}',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: amountColor,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                        Text(
                          'قەرز: ${_formatCurrency(entry.balanceAfter)}',
                          style: AppTextStyles.caption,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('کێشە هەیە: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(BuildContext context, Customer customer) {
    final ordersAsync = ref.watch(customerOrdersProvider(customer.id));
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersListProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('هەڵەیەک ڕوویدا: $error')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('هیچ پسوڵەیەکی کڕین بۆ ئەم کڕیارە نییە'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final order = orders[index];
              final salesmanName = order.salesman != null
                  ? order.salesman['name']
                  : 'نەناسراو';

              String statusLabel = 'ئامادەکردن';
              StatusBadgeType statusType = StatusBadgeType.warning;

              if (order.status == 'delivered') {
                statusLabel = 'گەیشتووە';
                statusType = StatusBadgeType.success;
              } else if (order.status == 'in_delivery') {
                statusLabel = 'لە ڕێگایە';
                statusType = StatusBadgeType.info;
              } else if (order.status == 'cancelled' ||
                  order.status == 'returned') {
                statusLabel = 'گەڕاوە';
                statusType = StatusBadgeType.danger;
              }

              return AppCard(
                onTap: () {
                  context.push('/order/${order.id}');
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            AppIcons.order,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'پسوڵەی #${order.orderNumber}',
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مەندوب: $salesmanName • ${order.createdAt.split('T').first}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع',
                            style: AppTextStyles.price,
                          ),
                          const SizedBox(height: 4),
                          StatusBadge(label: statusLabel, type: statusType),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
