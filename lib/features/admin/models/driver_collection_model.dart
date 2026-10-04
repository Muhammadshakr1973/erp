class DriverCashSummary {
  final Map<String, dynamic> driver;
  final int totalCollected;
  final int totalPaid;
  final int remainingAmount;

  DriverCashSummary({
    required this.driver,
    required this.totalCollected,
    required this.totalPaid,
    required this.remainingAmount,
  });

  factory DriverCashSummary.fromJson(Map<String, dynamic> json) {
    return DriverCashSummary(
      driver: json['driver'] as Map<String, dynamic>,
      totalCollected: (json['total_collected'] as num? ?? 0).toInt(),
      totalPaid: (json['total_paid'] as num? ?? 0).toInt(),
      remainingAmount: (json['remaining_amount'] as num? ?? 0).toInt(),
    );
  }
}

class DriverCollection {
  final int id;
  final int driverId;
  final String driverName;
  final int amount;
  final String collectedAt;
  final String collectorName;
  final String? notes;

  DriverCollection({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.amount,
    required this.collectedAt,
    required this.collectorName,
    this.notes,
  });

  factory DriverCollection.fromJson(Map<String, dynamic> json) {
    return DriverCollection(
      id: (json['id'] as num).toInt(),
      driverId: (json['driver_id'] as num).toInt(),
      driverName: json['driver'] != null ? (json['driver']['name'] as String? ?? 'شۆفێر') : 'شۆفێر',
      amount: (json['amount'] as num? ?? 0).toInt(),
      collectedAt: json['collected_at'] as String,
      collectorName: json['collector'] != null ? (json['collector']['name'] as String? ?? 'خاوەن') : 'خاوەن',
      notes: json['notes'] as String?,
    );
  }
}
