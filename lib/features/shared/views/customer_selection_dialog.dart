import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/components/app_text_field.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerSelectionDialog extends ConsumerStatefulWidget {
  const CustomerSelectionDialog({super.key});

  static Future<Customer?> show(BuildContext context) {
    return showDialog<Customer>(
      context: context,
      builder: (context) => const CustomerSelectionDialog(),
    );
  }

  @override
  ConsumerState<CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState
    extends ConsumerState<CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        width: double.maxFinite,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('دیاریکردنی کڕیار', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _searchController,
              hintText: 'گەڕان بەپێی ناوی کڕیار یان تەلەفۆن...',
              prefixIcon: AppIcons.search,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('هەڵە لە بارکردنی کڕیاران: $err')),
                data: (customers) {
                  final filtered = customers.where((c) {
                    final matchesName = c.name.toLowerCase().contains(
                      _searchQuery,
                    );
                    final matchesPhone = (c.phone ?? '').toLowerCase().contains(
                      _searchQuery,
                    );
                    return matchesName || matchesPhone;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('هیچ کڕیارێک نەدۆزرایەوە'));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(customer.name.substring(0, 1)),
                        ),
                        title: Text(
                          customer.name,
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text(customer.phone ?? 'بێ ژمارە'),
                        onTap: () {
                          Navigator.of(context).pop(customer);
                        },
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
