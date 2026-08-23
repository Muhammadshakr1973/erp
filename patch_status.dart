import 'dart:io';

void main() {
  var file = File('lib/features/admin/views/admin_orders_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll("status == 'DELIVERING'", "status == 'in_delivery'");
  content = content.replaceAll("status == 'CONFIRMED'", "status == 'confirmed'");
  content = content.replaceAll("status == 'DELIVERED'", "status == 'delivered'");
  content = content.replaceAll("status == 'CANCELLED'", "status == 'cancelled'");
  content = content.replaceAll("status == 'RETURNED'", "status == 'returned'");

  file.writeAsStringSync(content);
}
