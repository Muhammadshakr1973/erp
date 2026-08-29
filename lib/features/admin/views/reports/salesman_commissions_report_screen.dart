import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/models/user_model.dart';
import '../../../shared/models/commission_model.dart';
import '../providers/commission_provider.dart';
import '../providers/user_provider.dart';

class SalesmanCommissionsReportScreen extends ConsumerStatefulWidget {
  const SalesmanCommissionsReportScreen({super.key});

  @override
  ConsumerState<SalesmanCommissionsReportScreen> createState() => _SalesmanCommissionsReportScreenState();
}

class _SalesmanCommissionsReportScreenState extends ConsumerState<SalesmanCommissionsReportScreen> {
  int? _selectedSalesmanId;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    _filters = {};
  }

  void _applyFilters() {
    setState(() {
      _filters = {
        if (_selectedSalesmanId != null) 'salesman_id': _selectedSalesmanId.toString(),
        if (_selectedStatus != null && _selectedStatus != 'ALL') 'status': _selectedStatus,
        if (_startDate != null) 'period_from': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null) 'period_to': _endDate!.toIso8601String().split('T').first,
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSalesmanId = null;
      _selectedStatus = null;
      _startDate = null;
      _endDate = null;
      _filters = {};
    });
  }

  String _formatCurrency(num amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

  void _openCalculateDialog(BuildContext context, List<UserModel> salesmen) {
    int? dialogSalesmanId = _selectedSalesmanId ?? (salesmen.isNotEmpty ? salesmen.first.id : null);
    DateTime dialogStart = _startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime dialogEnd = _endDate ?? DateTime.now();
    final notesController = TextEditingController();

    bool isPreviewing = false;
    Map<String, dynamic>? previewData;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final notifier = ref.read(commissionActionProvider.notifier);

          Future<void> runPreview() async {
            if (dialogSalesmanId == null) {
              setDialogState(() => errorMessage = 'تکایە مەندوبێک هەڵبژێرە');
              return;
            }
            setDialogState(() {
              isPreviewing = true;
              errorMessage = null;
              previewData = null;
            });
            try {
              final result = await notifier.previewEligibleOrders(
                salesmanId: dialogSalesmanId!,
                periodFrom: dialogStart.toIso8601String().split('T').first,
                periodTo: dialogEnd.toIso8601String().split('T').first,
              );
              setDialogState(() {
                isPreviewing = false;
                previewData = result;
              });
            } catch (e) {
              setDialogState(() {
                isPreviewing = false;
                errorMessage = e.toString().replaceAll('Exception: ', '');
              });
            }
          }

          Future<void> submitCalculation() async {
            if (dialogSalesmanId == null) return;
            setDialogState(() {
              isPreviewing = true;
              errorMessage = null;
            });
            try {
              await notifier.calculateCommission(
                salesmanId: dialogSalesmanId!,
                periodFrom: dialogStart.toIso8601String().split('T').first,
                periodTo: dialogEnd.toIso8601String().split('T').first,
                notes: notesController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('کۆمسیۆن بەسەرکەوتوویی هەژمار کرا'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              setDialogState(() {
                isPreviewing = false;
                errorMessage = e.toString().replaceAll('Exception: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.calculate, color: AppColors.primary),
                SizedBox(width: 8),
                Text('هەژمارکردنی کۆمسیۆنی مەندوب', style: AppTextStyles.h3),
              ],
            ),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: dialogSalesmanId,
                      decoration: const InputDecoration(
                        labelText: 'مەندوب',
                        border: OutlineInputBorder(),
                      ),
                      items: salesmen.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.commissionRate ?? 0}%)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          dialogSalesmanId = val;
                          previewData = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: dialogStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setDialogState(() {
                                  dialogStart = p;
                                  previewData = null;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'لە بەرواری',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dialogStart.toIso8601String().split('T').first),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: dialogEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setDialogState(() {
                                  dialogEnd = p;
                                  previewData = null;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تا بەرواری',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dialogEnd.toIso8601String().split('T').first),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'تێبینی (ئارەزوومەندانە)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.remove_red_eye),
                        label: isPreviewing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('پێشبینینی پسوڵە شایستەکان'),
                        onPressed: isPreviewing ? null : runPreview,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: Text(errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ],
                    if (previewData != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ئەنجامی پێشبینیکردن:', style: AppTextStyles.bodyBold),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('ژمارەی پسوڵە گەیندراوەکان:'),
                                Text('${previewData!['eligible_orders_count'] ?? 0}', style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('کۆی فرۆشتن:'),
                                Text(_formatCurrency(previewData!['total_sales'] ?? 0), style: AppTextStyles.bodyMedium),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('کۆی قازانج:'),
                                Text(_formatCurrency(previewData!['total_profit'] ?? 0), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('ڕێژەی کۆمسیۆن:'),
                                Text('${previewData!['commission_rate'] ?? 0}%', style: AppTextStyles.bodyBold),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('کۆمسیۆنی هەژمارکراو:', style: AppTextStyles.h3),
                                Text(
                                  _formatCurrency(previewData!['estimated_commission'] ?? 0),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('پاشگەزبوونەوە'),
              ),
              AppButton(
                text: 'چەسپاندن و هەژمارکردن',
                onPressed: (previewData != null && !isPreviewing && (previewData!['eligible_orders_count'] ?? 0) > 0)
                    ? submitCalculation
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, CommissionModel commission) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('وردەکاری کۆمسیۆنی #${commission.id}', style: AppTextStyles.h3),
            _buildStatusChip(commission.status),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('مەندوب: ${commission.salesmanName}', style: AppTextStyles.bodyBold),
                          Text('ماوە: ${commission.periodFrom} تا ${commission.periodTo}'),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('کۆی فرۆشتن: ${_formatCurrency(commission.totalSales)}'),
                          Text('کۆی قازانج: ${_formatCurrency(commission.totalProfit)}', style: const TextStyle(color: AppColors.success)),
                          Text('ڕێژە: ${commission.commissionRate}%'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('بڕی کۆمسیۆن:', style: AppTextStyles.h3),
                          Text(_formatCurrency(commission.commissionAmount), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      if (commission.calculatedByName != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('هەژمارکراوە لەلایەن: ${commission.calculatedByName}'),
                            if (commission.approvedByName != null)
                              Text('پەسەندکراوە لەلایەن: ${commission.approvedByName}'),
                            if (commission.paidByName != null)
                              Text('دراوە لەلایەن: ${commission.paidByName} (${commission.paymentMethod ?? 'کاش'})'),
                          ],
                        ),
                      ],
                      if (commission.notes != null && commission.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('تێبینی: ${commission.notes!}', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      ],
                      if (commission.cancellationReason != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('هۆکاری هەڵوەشاندنەوە: ${commission.cancellationReason!}', style: const TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('پسوڵەکانی ناو ئەم کۆمسیۆنە:', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.sm),
                if (commission.details.isEmpty)
                  const Text('هیچ وردەکارییەکی پسوڵە نییە')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: AppTextStyles.bodyBold,
                      columns: const [
                        DataColumn(label: Text('ژمارەی پسوڵە')),
                        DataColumn(label: Text('کڕیار')),
                        DataColumn(label: Text('بڕی فرۆشتن')),
                        DataColumn(label: Text('قازانجی پسوڵە')),
                        DataColumn(label: Text('کۆمسیۆن')),
                      ],
                      rows: commission.details.map((d) {
                        return DataRow(cells: [
                          DataCell(Text(d.orderNumber ?? '#${d.salesOrderId}')),
                          DataCell(Text(d.customerName ?? 'کڕیار')),
                          DataCell(Text(_formatCurrency(d.salesAmount), textDirection: TextDirection.ltr)),
                          DataCell(Text(_formatCurrency(d.profitAmount), style: const TextStyle(color: AppColors.success), textDirection: TextDirection.ltr)),
                          DataCell(Text(_formatCurrency(d.commissionAmount), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr)),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  void _openApproveDialog(BuildContext context, CommissionModel commission) {
    final notesController = TextEditingController(text: commission.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پەسەندکردنی کۆمسیۆن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ئایا دڵنیایت لە پەسەندکردنی کۆمسیۆنی #${commission.id} بۆ مەندوب "${commission.salesmanName}" بە بڕی ${_formatCurrency(commission.commissionAmount)}؟'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'تێبینی پەسەندکردن (ئارەزوومەندانە)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('پاشگەزبوونەوە'),
          ),
          AppButton(
            text: 'پەسەندکردن',
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(commissionActionProvider.notifier).approveCommission(
                  commissionId: commission.id,
                  notes: notesController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('کۆمسیۆن بە سەرکەوتوویی پەسەند کرا'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openPayDialog(BuildContext context, CommissionModel commission) {
    String paymentMethod = 'cash';
    DateTime paidDate = DateTime.now();
    final notesController = TextEditingController(text: commission.notes);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('تۆمارکردنی پارەدانی کۆمسیۆن'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مەندوب: ${commission.salesmanName}', style: AppTextStyles.bodyBold),
              const SizedBox(height: 4),
              Text('بڕی کۆمسیۆن: ${_formatCurrency(commission.commissionAmount)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'شێوازی پارەدان',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('کاش / نەقد')),
                  DropdownMenuItem(value: 'bank', child: Text('حیسابی بانکی')),
                  DropdownMenuItem(value: 'transfer', child: Text('حەواڵە')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => paymentMethod = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'تێبینی پارەدان',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە'),
            ),
            AppButton(
              text: 'تۆمارکردنی دران',
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(commissionActionProvider.notifier).payCommission(
                    commissionId: commission.id,
                    paymentMethod: paymentMethod,
                    paidAt: paidDate.toIso8601String(),
                    notes: notesController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('پارەی کۆمسیۆن بە سەرکەوتوویی تۆمارکرا'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('هەڵە: ${e.toString().replaceAll("Exception: ", "")}'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCancelDialog(BuildContext context, CommissionModel commission) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هەڵوەشاندنەوەی کۆمسیۆن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ئاگاداری: هەڵوەشاندنەوەی کۆمسیۆن دەبێتە هۆی ئازادکردنەوەی هەموو ئەو پسوڵانەی لەم خولەدا بوون تا لە خولێکی نوێدا هەژمار بکرێنەوە.',
              style: TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'هۆکاری هەڵوەشاندنەوە (پێویستە)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('هەڵوەشاندنەوە', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تکایە هۆکاری هەڵوەشاندنەوە بنووسە')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(commissionActionProvider.notifier).cancelCommission(
                  commissionId: commission.id,
                  reason: reason,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('کۆمسیۆنەکە هەڵوەشێنرایەوە'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('هەڵە: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commissionsAsync = ref.watch(commissionsListProvider(_filters));
    final summaryAsync = ref.watch(commissionSummaryProvider(_filters));
    final salesmenAsync = ref.watch(salesmenListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ڕاپۆرت و بەڕێوەبردنی کۆمسیۆنی مەندوبەکان', style: AppTextStyles.h2),
        actions: [
          salesmenAsync.when(
            data: (salesmen) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_chart),
                label: const Text('هەژمارکردنی کۆمسیۆن'),
                onPressed: () => _openCalculateDialog(context, salesmen),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          children: [
            // KPI Summary Cards
            summaryAsync.when(
              data: (summary) {
                final calculated = summary['calculated'] as Map<String, dynamic>? ?? {};
                final approved = summary['approved'] as Map<String, dynamic>? ?? {};
                final paid = summary['paid'] as Map<String, dynamic>? ?? {};

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;

                    final cards = [
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('هەژمارکراو (چاوەڕوانکراو)', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(calculated['amount'] ?? 0),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warning),
                                textDirection: TextDirection.ltr,
                              ),
                              Text('${calculated['count'] ?? 0} کۆمسیۆن', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('پەسەندکراو (ئامادەی پارەدان)', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(approved['amount'] ?? 0),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.info),
                                textDirection: TextDirection.ltr,
                              ),
                              Text('${approved['count'] ?? 0} کۆمسیۆن', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('دراو (تەواوبوو)', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(paid['amount'] ?? 0),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                                textDirection: TextDirection.ltr,
                              ),
                              Text('${paid['count'] ?? 0} کۆمسیۆن', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ),
                    ];

                    if (isMobile) {
                      return Column(
                        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
                      );
                    }

                    return Row(children: cards);
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Filters Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('فلتەرکردن', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('پاککردنەوە', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;

                      final salesmanDropdown = salesmenAsync.when(
                        data: (salesmen) => DropdownButtonFormField<int?>(
                          initialValue: _selectedSalesmanId,
                          decoration: const InputDecoration(
                            labelText: 'مەندوب',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('گشت مەندوبەکان')),
                            ...salesmen.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedSalesmanId = val),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );

                      final statusDropdown = DropdownButtonFormField<String?>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'دۆخی کۆمسیۆن',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('گشت دۆخەکان')),
                          DropdownMenuItem(value: 'calculated', child: Text('هەژمارکراو')),
                          DropdownMenuItem(value: 'approved', child: Text('پەسەندکراو')),
                          DropdownMenuItem(value: 'paid', child: Text('دراوە')),
                          DropdownMenuItem(value: 'cancelled', child: Text('هەڵوەشێنراوە')),
                        ],
                        onChanged: (val) => setState(() => _selectedStatus = val),
                      );

                      final startPicker = InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'لە بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          child: Text(_startDate != null ? _startDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
                        ),
                      );

                      final endPicker = InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تا بەرواری',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          child: Text(_endDate != null ? _endDate!.toIso8601String().split('T').first : 'دیارینەکراوە'),
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            salesmanDropdown,
                            const SizedBox(height: AppSpacing.sm),
                            statusDropdown,
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(child: startPicker),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: endPicker),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(text: 'جێبەجێکردن', onPressed: _applyFilters),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(flex: 2, child: salesmanDropdown),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(flex: 2, child: statusDropdown),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(flex: 2, child: startPicker),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(flex: 2, child: endPicker),
                              const SizedBox(width: AppSpacing.sm),
                              AppButton(text: 'فلتەر', onPressed: _applyFilters),
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

            // Results List / Table
            Expanded(
              child: AppCard(
                child: commissionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('هەڵەیەک ڕوویدا: $e')),
                  data: (commissions) {
                    if (commissions.isEmpty) {
                      return const Center(child: Text('هیچ کۆمسیۆنێک نەدۆزرایەوە', style: AppTextStyles.h3));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingTextStyle: AppTextStyles.bodyBold,
                          dataTextStyle: AppTextStyles.bodyMedium,
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('مەندوب')),
                            DataColumn(label: Text('ماوە')),
                            DataColumn(label: Text('کۆی فرۆشتن')),
                            DataColumn(label: Text('کۆی قازانج')),
                            DataColumn(label: Text('ڕێژە')),
                            DataColumn(label: Text('بڕی کۆمسیۆن')),
                            DataColumn(label: Text('دۆخ')),
                            DataColumn(label: Text('کردارەکان')),
                          ],
                          rows: commissions.map((c) {
                            return DataRow(
                              cells: [
                                DataCell(Text('#${c.id}')),
                                DataCell(Text(c.salesmanName)),
                                DataCell(Text('${c.periodFrom} / ${c.periodTo}')),
                                DataCell(Text(_formatCurrency(c.totalSales), textDirection: TextDirection.ltr)),
                                DataCell(Text(_formatCurrency(c.totalProfit), style: const TextStyle(color: AppColors.success), textDirection: TextDirection.ltr)),
                                DataCell(Text('${c.commissionRate}%')),
                                DataCell(Text(_formatCurrency(c.commissionAmount), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr)),
                                DataCell(_buildStatusChip(c.status)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 20, color: AppColors.primary),
                                        tooltip: 'بینینی وردەکاری پسوڵەکان',
                                        onPressed: () => _showDetailsDialog(context, c),
                                      ),
                                      if (c.status == 'calculated') ...[
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.info),
                                          tooltip: 'پەسەندکردن',
                                          onPressed: () => _openApproveDialog(context, c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.danger),
                                          tooltip: 'هەڵوەشاندنەوە',
                                          onPressed: () => _openCancelDialog(context, c),
                                        ),
                                      ],
                                      if (c.status == 'approved') ...[
                                        IconButton(
                                          icon: const Icon(Icons.payment, size: 20, color: AppColors.success),
                                          tooltip: 'تۆمارکردنی پارەدان',
                                          onPressed: () => _openPayDialog(context, c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.danger),
                                          tooltip: 'هەڵوەشاندنەوە',
                                          onPressed: () => _openCancelDialog(context, c),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
