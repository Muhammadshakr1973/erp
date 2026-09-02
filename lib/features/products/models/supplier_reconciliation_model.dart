class SupplierReconciliationModel {
  final bool isConsistent;
  final int storedBalance;
  final int recalculatedBalance;
  final List<String> discrepancies;

  SupplierReconciliationModel({
    required this.isConsistent,
    required this.storedBalance,
    required this.recalculatedBalance,
    required this.discrepancies,
  });

  factory SupplierReconciliationModel.fromJson(Map<String, dynamic> json) {
    return SupplierReconciliationModel(
      isConsistent: json['is_consistent'] ?? false,
      storedBalance: json['stored_balance'] ?? 0,
      recalculatedBalance: json['recalculated_balance'] ?? 0,
      discrepancies: List<String>.from(json['discrepancies'] ?? []),
    );
  }
}
