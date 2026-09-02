class CustomerReconciliationModel {
  final bool isConsistent;
  final double storedBalance;
  final double recalculatedBalance;
  final List<String> discrepancies;

  CustomerReconciliationModel({
    required this.isConsistent,
    required this.storedBalance,
    required this.recalculatedBalance,
    required this.discrepancies,
  });

  factory CustomerReconciliationModel.fromJson(Map<String, dynamic> json) {
    return CustomerReconciliationModel(
      isConsistent: json['is_consistent'] ?? false,
      storedBalance: double.tryParse(json['stored_balance']?.toString() ?? '0') ?? 0.0,
      recalculatedBalance: double.tryParse(json['recalculated_balance']?.toString() ?? '0') ?? 0.0,
      discrepancies: List<String>.from(json['discrepancies'] ?? []),
    );
  }

  double get discrepancyAmount => (storedBalance - recalculatedBalance).abs();
}
