import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/app_button.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../admin/views/providers/reports_provider.dart';
import '../models/customer.dart';
import '../models/route_model.dart';
import '../providers/customer_provider.dart';
import '../providers/route_provider.dart';
import 'map_picker_dialog.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPaying = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _phone2Controller;
  late TextEditingController _addressController;
  late TextEditingController _imageUrlController;
  late TextEditingController _initialDebtController;

  late TextEditingController _paymentAmountController;
  late TextEditingController _paymentNotesController;

  String _priceType = 'N3';
  int? _routeId;
  double? _latitude;
  double? _longitude;

  String? _ledgerEntryType;
  DateTime? _ledgerStartDate;
  DateTime? _ledgerEndDate;
  Map<String, dynamic> _ledgerFilters = {};

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _ledgerFilters = {'customer_id': widget.customer!.id.toString()};
    }
    _nameController = TextEditingController(text: widget.customer?.name);
    _phoneController = TextEditingController(text: widget.customer?.phone);
    _phone2Controller = TextEditingController(text: widget.customer?.phone2);
    _addressController = TextEditingController(text: widget.customer?.address);
    _imageUrlController = TextEditingController(text: widget.customer?.imageUrl);
    _initialDebtController = TextEditingController();
    _priceType = widget.customer?.priceType ?? 'N3';
    _routeId = widget.customer?.routeId;
    _latitude = widget.customer?.latitude;
    _longitude = widget.customer?.longitude;

    _paymentAmountController = TextEditingController();
    _paymentNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _imageUrlController.dispose();
    _initialDebtController.dispose();
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(customerActionsProvider);
      if (widget.customer == null) {
        final initialDebt = int.tryParse(_initialDebtController.text.trim());
        await actions.addCustomer(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          routeId: _routeId,
          priceType: _priceType,
          initialDebt: initialDebt,
          latitude: _latitude,
          longitude: _longitude,
        );
      } else {
        await actions.updateCustomer(
          widget.customer!.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          routeId: _routeId,
          priceType: _priceType,
          latitude: _latitude,
          longitude: _longitude,
        );
      }

      if (mounted) {
        ref.invalidate(customerListProvider);
        if (widget.customer != null) {
          ref.invalidate(singleCustomerProvider(widget.customer!.id));
        }
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null ? 'کڕیار بەسەرکەوتوویی زیادکرا' : 'زانیاری کڕیار نوێکرایەوە'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کێشە لە پاشەکەوتکردن: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_paymentFormKey.currentState!.validate()) {
      return;
    }

    final amountText = _paymentAmountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تکایە بڕێکی دروست بنووسە')),
      );
      return;
    }

    setState(() => _isPaying = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.client.post('/payments', data: {
        'customer_id': widget.customer!.id,
        'amount': amount,
        'notes': _paymentNotesController.text.trim().isEmpty ? null : _paymentNotesController.text.trim(),
        'payment_method': 'CASH',
      });

      if (response.statusCode == 201) {
        ref.invalidate(customerListProvider);
        if (widget.customer != null) {
          ref.invalidate(singleCustomerProvider(widget.customer!.id));
          ref.invalidate(customerDebtsReportProvider(_ledgerFilters));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('پارەدانەکە بە سەرکەوتوویی تۆمارکرا')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کێشە لە نوێکردنەوەی قەرز: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  void _applyLedgerFilters() {
    setState(() {
      _ledgerFilters = {
        'customer_id': widget.customer!.id.toString(),
        if (_ledgerEntryType != null && _ledgerEntryType != 'ALL') 'entry_type': _ledgerEntryType,
        if (_ledgerStartDate != null) 'start_date': _ledgerStartDate!.toIso8601String().split('T').first,
        if (_ledgerEndDate != null) 'end_date': _ledgerEndDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearLedgerFilters() {
    setState(() {
      _ledgerEntryType = null;
      _ledgerStartDate = null;
      _ledgerEndDate = null;
      _ledgerFilters = {'customer_id': widget.customer!.id.toString()};
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final childWidget = widget.customer == null
        ? _buildProfileForm(context)
        : DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('بەڕێوەبردنی کڕیار', style: AppTextStyles.h2),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TabBar(
                  tabs: const [
                    Tab(text: 'زانیاری'),
                    Tab(text: 'پارەدان'),
                    Tab(text: 'مێژوو'),
                  ],
                  labelStyle: AppTextStyles.bodyBold,
                  unselectedLabelStyle: AppTextStyles.bodyMedium,
                  labelColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SizedBox(
                    height: 420,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: _buildProfileFormFields(context)),
                        SingleChildScrollView(child: _buildDebtForm(context)),
                        _buildLedgerHistory(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: isMobile ? double.infinity : 520,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: childWidget,
        ),
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('زیادکردنی کڕیاری نوێ', style: AppTextStyles.h2),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: _buildProfileFormFields(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 140,
                child: AppButton(
                  text: 'پاشەکەوت',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('پاشگەزبوونەوە'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFormFields(BuildContext context) {
    return Form(
      key: widget.customer == null ? null : _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            labelText: 'ناوی کڕیار / مارکێت',
            hintText: 'نموونە: مارکێتی بێستون',
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'تکایە ناوی کڕیار بنووسە';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _phoneController,
                  labelText: 'ژمارەی مۆبایل',
                  hintText: '0750 ...',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _phone2Controller,
                  labelText: 'ژمارەی دووەم (ئارەزوومەندانە)',
                  hintText: '0770 ...',
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _addressController,
                  labelText: 'ناونیشان / شوێن',
                  hintText: 'هەولێر، گەڕەکی ڕزگاری...',
                  prefixIcon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _latitude != null ? Colors.green.shade50 : Colors.blue.shade50,
                  foregroundColor: _latitude != null ? Colors.green : Colors.blue,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _latitude != null ? Colors.green.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onPressed: () async {
                  final LatLng? initialLoc = _latitude != null && _longitude != null
                      ? LatLng(_latitude!, _longitude!)
                      : null;
                  final result = await showDialog<LatLng>(
                    context: context,
                    builder: (context) => MapPickerDialog(initialLocation: initialLoc),
                  );
                  if (result != null) {
                    setState(() {
                      _latitude = result.latitude;
                      _longitude = result.longitude;
                    });
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _latitude != null ? 'دیاریکراوە' : 'دیاریکردن',
                  style: const TextStyle(fontFamily: 'Rudaw'),
                ),
              ),
            ],
          ),
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'پۆتانەکان: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontFamily: 'Rudaw',
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _latitude = null;
                        _longitude = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('سڕینەوە', style: TextStyle(fontSize: 12, fontFamily: 'Rudaw')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _imageUrlController,
            labelText: 'بەستەری وێنەی کڕیار (ئارەزوومەندانە)',
            hintText: 'https://example.com/image.jpg',
            prefixIcon: Icons.image_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _priceType,
            decoration: const InputDecoration(
              labelText: 'جۆری نرخ',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'N1', child: Text('نرخی یەکەم (N1 - تاک)')),
              DropdownMenuItem(value: 'N2', child: Text('نرخی دووەم (N2 - کۆ)')),
              DropdownMenuItem(value: 'N3', child: Text('نرخی سێیەم (N3 - تایبەت)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _priceType = val);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ref.watch(routeListProvider).when(
            data: (routes) => DropdownButtonFormField<int>(
              value: _routeId != null && routes.any((r) => r.id == _routeId) ? _routeId : null,
              decoration: const InputDecoration(
                labelText: 'گەڕەک / ڕاوت',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: Icon(Icons.alt_route),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('گەڕەک دیاری نەکراوە'),
                ),
                ...routes.map((route) => DropdownMenuItem<int>(
                      value: route.id,
                      child: Text('${route.name} (${route.code})'),
                    )),
              ],
              onChanged: (val) {
                setState(() => _routeId = val);
              },
            ),
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Text(
              'کێشە لە بارکردنی ڕاوتەکان: $err',
              style: const TextStyle(color: Colors.red, fontFamily: 'Rudaw'),
            ),
          ),
          if (widget.customer == null) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _initialDebtController,
              labelText: 'قەرزی پێشینە / قەرزی سەرەتا (د.ع)',
              hintText: '0',
              prefixIcon: Icons.account_balance_wallet_outlined,
              keyboardType: TextInputType.number,
            ),
          ],
          if (widget.customer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'پاشەکەوتکردنی گۆڕانکارییەکان',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtForm(BuildContext context) {
    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: Column(
              children: [
                const Text('بڕی قەرزی ئێستای کڕیار', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(widget.customer?.balance ?? 0),
                  style: AppTextStyles.priceLarge.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('تۆمارکردنی پارەدان', style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _paymentAmountController,
            labelText: 'بڕی پارە',
            hintText: 'نموونە: 150000',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'تکایە بڕی پارەی دراو بنووسە';
              }
              if (int.tryParse(value) == null) {
                return 'تکایە تەنها ژمارە بنووسە';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _paymentNotesController,
            labelText: 'تێبینی پارەدان',
            hintText: 'تێبینی بنووسە لێرە ...',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'تۆمارکردنی پارەدان',
            isLoading: _isPaying,
            onPressed: _submitPayment,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerHistory(BuildContext context) {
    if (widget.customer == null) {
      return const SizedBox.shrink();
    }

    final ledgerAsync = ref.watch(customerDebtsReportProvider(_ledgerFilters));

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // Filter UI
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('گشتی')),
                        DropdownMenuItem(value: 'PAYMENT', child: Text('پارەدان')),
                        DropdownMenuItem(value: 'SALE', child: Text('فرۆشتن')),
                        DropdownMenuItem(value: 'RETURN', child: Text('گەڕانەوە')),
                        DropdownMenuItem(value: 'ADJUSTMENT', child: Text('ڕاستکردنەوە')),
                      ],
                      onChanged: (val) => setState(() => _ledgerEntryType = val),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(_ledgerStartDate != null ? _ledgerStartDate!.toIso8601String().split('T').first : 'دیارینەکراوە', style: AppTextStyles.caption),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(_ledgerEndDate != null ? _ledgerEndDate!.toIso8601String().split('T').first : 'دیارینەکراوە', style: AppTextStyles.caption),
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
                    child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
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
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ledgerAsync.when(
            data: (ledgerList) {
              if (ledgerList.isEmpty) {
                return const Center(child: Text('هیچ مێژوویەک نییە'));
              }
              return ListView.separated(
                itemCount: ledgerList.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = ledgerList[index];
                  final isCredit = entry.type == 'credit';
                  final amountColor = isCredit ? AppColors.success : AppColors.danger;

                  String entryTypeLabel = entry.entryType;
                  if (entryTypeLabel == 'PAYMENT') entryTypeLabel = 'پارەدان';
                  if (entryTypeLabel == 'SALE') entryTypeLabel = 'فرۆشتن';
                  if (entryTypeLabel == 'RETURN') entryTypeLabel = 'گەڕانەوە';
                  if (entryTypeLabel == 'ADJUSTMENT') entryTypeLabel = 'ڕاستکردنەوە/قەرزی سەرەتا';

                  return ListTile(
                    title: Text(entry.description ?? entryTypeLabel, style: AppTextStyles.bodyBold),
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
                          style: AppTextStyles.bodyBold.copyWith(color: amountColor),
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
}
