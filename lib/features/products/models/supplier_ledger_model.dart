class SupplierLedgerModel {
  final int id;
  final int supplierId;
  final String entryType;
  final String? type;
  final int debit;
  final int credit;
  final int amount;
  final int balanceAfter;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final String? createdAt;
  final String? supplierName;

  SupplierLedgerModel({
    required this.id,
    required this.supplierId,
    required this.entryType,
    this.type,
    required this.debit,
    required this.credit,
    required this.amount,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.description,
    this.createdAt,
    this.supplierName,
  });

  factory SupplierLedgerModel.fromJson(Map<String, dynamic> json) {
    return SupplierLedgerModel(
      id: json['id'] ?? 0,
      supplierId: json['supplier_id'] ?? 0,
      entryType: json['entry_type'] ?? '',
      type: json['type'],
      debit: json['debit'] ?? 0,
      credit: json['credit'] ?? 0,
      amount: json['amount'] ?? 0,
      balanceAfter: json['balance_after'] ?? 0,
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      description: json['description'],
      createdAt: json['created_at'],
      supplierName: json['supplier'] != null ? json['supplier']['name'] : null,
    );
  }
}
