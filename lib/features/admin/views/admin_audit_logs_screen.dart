import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/app_card.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/audit_log_provider.dart';
import '../../../core/utils/formatters.dart';

class AdminAuditLogsScreen extends ConsumerWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تۆماری گۆڕانکارییەکان (Audit Logs)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(auditLogsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auditLogsProvider);
          await ref.read(auditLogsProvider.future);
        },
        child: auditLogsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text(err.toString())),
          data: (logs) {
            if (logs.isEmpty) {
              return const Center(
                child: Text('هیچ تۆمارێک نەدۆزرایەوە', style: AppTextStyles.body),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final log = logs[index];
                final String action = log['action'] ?? 'N/A';
                final String entity = log['entity_type'] ?? 'N/A';
                final String date = Formatters.date(DateTime.parse(log['created_at']));

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$action - $entity', style: AppTextStyles.bodyBold),
                          Text(date, style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'بەکارهێنەر: ${log['user']?['name'] ?? 'سیستەم'}',
                        style: AppTextStyles.body,
                      ),
                      if (log['payload'] != null)
                        Padding(
                          padding: const EdgeInsets.top(AppSpacing.xs),
                          child: Text(
                            log['payload'].toString(),
                            style: AppTextStyles.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
