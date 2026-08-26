class CustomerLedgerModel {
  final int id;
  final int customerId;
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
  final String? customerName;

  CustomerLedgerModel({
    required this.id,
    required this.customerId,
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
    this.customerName,
  });

  factory CustomerLedgerModel.fromJson(Map<String, dynamic> json) {
    return CustomerLedgerModel(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
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
      customerName: json['customer'] != null ? json['customer']['name'] : null,
    );
  }
}
