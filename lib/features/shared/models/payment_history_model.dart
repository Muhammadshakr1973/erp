class PaymentHistoryModel {
  final int id;
  final String type; // 'customer' or 'supplier'
  final String partyName;
  final int partyId;
  final num amount;
  final String paymentMethod;
  final String paidAt;
  final String? notes;
  final String reference;

  PaymentHistoryModel({
    required this.id,
    required this.type,
    required this.partyName,
    required this.partyId,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    this.notes,
    required this.reference,
  });

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      partyName: json['party_name'] ?? 'نەزانراو',
      partyId: json['party_id'] ?? 0,
      amount: json['amount'] ?? 0,
      paymentMethod: json['payment_method'] ?? '',
      paidAt: json['paid_at'] ?? '',
      notes: json['notes'],
      reference: json['reference'] ?? '',
    );
  }
}
