import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_text_field.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/error_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import 'providers/driver_collection_provider.dart';
import '../models/driver_collection_model.dart';

class AdminDriverCollectionsScreen extends ConsumerStatefulWidget {
  const AdminDriverCollectionsScreen({super.key});

  @override
  ConsumerState<AdminDriverCollectionsScreen> createState() =>
      _AdminDriverCollectionsScreenState();
}

class _AdminCollectionsTab {
  final String label;
  final IconData icon;

  const _AdminCollectionsTab({required this.label, required this.icon});
}

class _AdminDriverCollectionsScreenState
    extends ConsumerState<AdminDriverCollectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<_AdminCollectionsTab> _tabs = [
    _AdminCollectionsTab(label: 'کورتەی شۆفێرەکان', icon: Icons.people_outline),
    _AdminCollectionsTab(label: 'تۆماری پارە وەرگرتنەکان', icon: Icons.history_edu_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حیساباتی پارەی شۆفێرەکان'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: AppTextStyles.bodyBold,
          tabs: _tabs
              .map((tab) => Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tab.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(tab.label),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDriversSummaryTab(),
          _buildCollectionsHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildDriversSummaryTab() {
    final summariesAsync = ref.watch(driverCashSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverCashSummaryProvider);
      },
      child: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'هەڵەیەک ڕوویدا',
            message: Formatters.cleanError(err),
            onRetry: () => ref.invalidate(driverCashSummaryProvider),
          ),
        ),
        data: (summaries) {
          if (summaries.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'هیچ شۆفێرێک نییە',
                message: 'هیچ شۆفێرێکی چالاک لە سیستەمەکەدا نەدۆزرایەوە.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: summaries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              final driverName = summary.driver['name'] ?? 'شۆفێر';
              final driverPhone = summary.driver['phone'] ?? '';

              // Remaining amount is what's still with the driver
              final outstandingAmount = summary.remainingAmount;
              final bool hasOutstanding = outstandingAmount > 0;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver Info Header
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          child: Icon(
                            Icons.directions_car_filled_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName, style: AppTextStyles.bodyBold),
                              if (driverPhone.isNotEmpty)
                                Text(
                                  driverPhone,
                                  style: AppTextStyles.caption,
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showCollectCashDialog(context, summary),
                          icon: const Icon(Icons.add_card, size: 16),
                          label: const Text('وەرگرتنی پارە'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg),

                    // Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCol(
                            title: 'وەرگیراو لە کڕیار',
                            value: summary.totalCollected,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _buildMetricCol(
                            title: 'ڕادەستکراو بە ئۆفیس',
                            value: summary.totalPaid,
                            color: AppColors.success,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _buildMetricCol(
                            title: 'پارەی لای شۆفێر',
                            value: outstandingAmount,
                            color: hasOutstanding ? AppColors.danger : AppColors.primary,
                            isBold: true,
                          ),
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
    );
  }

  Widget _buildMetricCol({
    required String title,
    required int value,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.currency(value),
          style: (isBold ? AppTextStyles.bodyBold : AppTextStyles.bodyMedium)
              .copyWith(color: color, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCollectionsHistoryTab() {
    final historyAsync = ref.watch(driverCollectionsHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverCollectionsHistoryProvider);
      },
      child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: ErrorState(
            title: 'هەڵەیەک ڕوویدا',
            message: Formatters.cleanError(err),
            onRetry: () => ref.invalidate(driverCollectionsHistoryProvider),
          ),
        ),
        data: (collections) {
          if (collections.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'هیچ تۆمارێک نییە',
                message: 'تا ئێستا هیچ کۆی پارەیەک لە هیچ شۆفێرێک وەرنەگیراوە.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final col = collections[index];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(col.driverName, style: AppTextStyles.bodyBold),
                        Text(
                          Formatters.currency(col.amount),
                          style: AppTextStyles.price.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'وەرگرتنەوە لەلایەن: ${col.collectorName}',
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          col.collectedAt,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    if (col.notes != null && col.notes!.isNotEmpty) ...[
                      const Divider(height: 12),
                      Text(
                        'تێبینی: ${col.notes}',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCollectCashDialog(BuildContext context, DriverCashSummary summary) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    // Prefill with outstanding amount for easier reconciliation
    if (summary.remainingAmount > 0) {
      amountController.text = summary.remainingAmount.toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وەرگرتنی پارە لە ${summary.driver['name']}',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'کۆی پارەی ماوە لەلای شۆفێر: ${Formatters.currency(summary.remainingAmount)}',
                      style: AppTextStyles.caption.copyWith(
                        color: summary.remainingAmount > 0 ? AppColors.danger : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: amountController,
                      labelText: 'بڕی پارەی وەرگیراو (دینار)',
                      hintText: 'نموونە: 250000',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'تکایە بڕی پارەکە بنووسە';
                        }
                        final amount = int.tryParse(value.replaceAll(',', '').trim());
                        if (amount == null || amount <= 0) {
                          return 'تکایە ژمارەیەکی دروست بنووسە';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: notesController,
                      labelText: 'تێبینی (ئارەزوومەندانە)',
                      hintText: 'بۆ نموونە: تەسلیمکردنی پارەی تریپی ڕۆژی دووشەممە',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('پەشیمانبوونەوە'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          final amount = int.parse(
                              amountController.text.replaceAll(',', '').trim());

                          try {
                            final todayStr = DateTime.now().toIso8601String().split('T')[0];
                            await ref
                                .read(driverCollectionActionsProvider)
                                .storeCollection(
                                  driverId: summary.driver['id'] as int,
                                  amount: amount,
                                  collectedAt: todayStr,
                                  notes: notesController.text.trim(),
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'پارەکە بەسەرکەوتوویی لە شۆفێر وەرگیرا و تۆمارکرا',
                                    style: TextStyle(fontFamily: 'Rudaw'),
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تۆمارکردن سەرکەوتوو نەبوو: $e',
                                    style: const TextStyle(fontFamily: 'Rudaw'),
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('تۆمارکردن'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
