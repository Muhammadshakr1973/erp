import 'dart:io';

void main() {
  var file = File('lib/features/admin/views/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    "import '../../auth/providers/auth_provider.dart';",
    "import '../../auth/providers/auth_provider.dart';\nimport '../providers/dashboard_provider.dart';"
  );
  
  content = content.replaceFirst(
    "final theme = Theme.of(context);",
    "final theme = Theme.of(context);\n    final dashboardAsync = ref.watch(dashboardProvider);"
  );
  
  content = content.replaceFirst(
    "body: SingleChildScrollView(",
    "body: RefreshIndicator(\n        onRefresh: () async => ref.invalidate(dashboardProvider),\n        child: SingleChildScrollView("
  );
  
  content = content.replaceFirst(
    "// Top Stats Grid",
    "// Top Stats Grid\n            dashboardAsync.when(\n              loading: () => const Center(child: CircularProgressIndicator()),\n              error: (err, stack) => Center(child: Text('هەڵەیەک ڕوویدا: \$err')),\n              data: (dashboard) => "
  );
  
  content = content.replaceFirst(
    "value: '1,250,000',",
    "value: dashboard.monthlySales.toInt().toString(),"
  );
  content = content.replaceFirst(
    "title: 'فرۆشتنی ئەمڕۆ',",
    "title: 'فرۆشتنی ئەم مانگە',"
  );
  content = content.replaceFirst(
    "value: '4,500,000',",
    "value: dashboard.totalReceivables.toInt().toString(),"
  );
  content = content.replaceFirst(
    "title: 'قەرزی بازاڕ',",
    "title: 'کۆی قەرزی بازاڕ',"
  );
  
  content = content.replaceFirst(
    "title: 'گەشتەکانی ئەمڕۆ',",
    "title: 'قازانجی مانگ',"
  );
  content = content.replaceFirst(
    "value: '4',",
    "value: dashboard.monthlyProfit.toInt().toString(),\n                      currency: 'د.ع',"
  );
  
  content = content.replaceFirst(
    "title: 'کاڵای کەمبوو',",
    "title: 'پارەی وەرگیراو',"
  );
  content = content.replaceFirst(
    "value: '12',",
    "value: dashboard.monthlyCollected.toInt().toString(),\n                      currency: 'د.ع',"
  );
  
  content = content.replaceFirst(
    "              },",
    "              },\n            ),\n"
  );
  
  file.writeAsStringSync(content);
}
