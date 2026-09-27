import 'dart:convert';

class SyncQueueEntry {
  final String id;
  final String entityId;
  final String operationType;
  final String payloadJson;
  final DateTime createdAt;
  String status; // 'PENDING', 'SYNCING', 'COMPLETED', 'FAILED'
  int retryCount;
  String? errorInformation;
  Map<String, dynamic>? syncResult;

  SyncQueueEntry({
    required this.id,
    required this.entityId,
    required this.operationType,
    required this.payloadJson,
    required this.createdAt,
    this.status = 'PENDING',
    this.retryCount = 0,
    this.errorInformation,
    this.syncResult,
  });

  Map<String, dynamic> get payload {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityId': entityId,
      'operationType': operationType,
      'payloadJson': payloadJson,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'retryCount': retryCount,
      'errorInformation': errorInformation,
      'syncResult': syncResult,
    };
  }

  factory SyncQueueEntry.fromMap(Map<String, dynamic> map) {
    return SyncQueueEntry(
      id: map['id']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      operationType: map['operationType']?.toString() ?? '',
      payloadJson: map['payloadJson']?.toString() ?? '{}',
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: map['status']?.toString() ?? 'PENDING',
      retryCount: map['retryCount'] is int ? map['retryCount'] as int : 0,
      errorInformation: map['errorInformation']?.toString(),
      syncResult: map['syncResult'] is Map
          ? Map<String, dynamic>.from(map['syncResult'] as Map)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SyncQueueEntry.fromJson(String source) =>
      SyncQueueEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);

  SyncQueueEntry copyWith({
    String? id,
    String? entityId,
    String? operationType,
    String? payloadJson,
    DateTime? createdAt,
    String? status,
    int? retryCount,
    String? errorInformation,
    Map<String, dynamic>? syncResult,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorInformation: errorInformation ?? this.errorInformation,
      syncResult: syncResult ?? this.syncResult,
    );
  }
}
