import '../../orders/models/order_model.dart';
import '../../auth/models/user_model.dart';

class DeliveryTripModel {
  final int id;
  final String tripNumber;
  final int driverId;
  final String tripDate;
  final String status;
  final int totalOrders;
  final int totalAmountCollected;
  final String? notes;
  final List<DeliveryTripOrderModel> orders;
  final UserModel? driver;
  final String? driverName;

  DeliveryTripModel({
    required this.id,
    required this.tripNumber,
    required this.driverId,
    required this.tripDate,
    required this.status,
    required this.totalOrders,
    required this.totalAmountCollected,
    this.notes,
    required this.orders,
    this.driver,
    this.driverName,
  });

  factory DeliveryTripModel.fromJson(Map<String, dynamic> json) {
    var ordersList = json['orders'] as List? ?? [];
    List<DeliveryTripOrderModel> parsedOrders =
        ordersList.map((i) => DeliveryTripOrderModel.fromJson(i)).toList();

    UserModel? driverObj;
    String? driverNameVal;
    if (json['driver'] != null && json['driver'] is Map) {
      driverObj = UserModel.fromJson(Map<String, dynamic>.from(json['driver'] as Map));
      driverNameVal = driverObj.name;
    } else if (json['driver_name'] != null) {
      driverNameVal = json['driver_name'].toString();
    }

    return DeliveryTripModel(
      id: json['id'] ?? 0,
      tripNumber: json['trip_number'] ?? '',
      driverId: json['driver_id'] ?? 0,
      tripDate: json['trip_date']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PLANNED',
      totalOrders: json['total_orders'] ?? 0,
      totalAmountCollected: json['total_amount_collected'] ?? 0,
      notes: json['notes'],
      orders: parsedOrders,
      driver: driverObj,
      driverName: driverNameVal,
    );
  }
}

class DeliveryTripOrderModel {
  final int id;
  final int deliveryTripId;
  final int salesOrderId;
  final String status;
  final int deliveryOrder;
  final int receivedAmount;
  final String? failedReason;
  final String? notes;
  final OrderModel? order;

  DeliveryTripOrderModel({
    required this.id,
    required this.deliveryTripId,
    required this.salesOrderId,
    required this.status,
    required this.deliveryOrder,
    required this.receivedAmount,
    this.failedReason,
    this.notes,
    this.order,
  });

  factory DeliveryTripOrderModel.fromJson(Map<String, dynamic> json) {
    return DeliveryTripOrderModel(
      id: json['id'] ?? 0,
      deliveryTripId: json['delivery_trip_id'] ?? 0,
      salesOrderId: json['sales_order_id'] ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      deliveryOrder: json['delivery_order'] ?? 0,
      receivedAmount: json['received_amount'] ?? 0,
      failedReason: json['failed_reason'],
      notes: json['notes'],
      order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
    );
  }
}
