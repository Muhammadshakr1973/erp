import 'dart:convert';

import 'package:hive/hive.dart';

part 'sync_queue_entry.g.dart';

@HiveType(typeId: 0)
class SyncQueueEntry extends HiveObject {
  @HiveField(0)
  String id; // unique operation ID

  @HiveField(1)
  String? entityId;

  @HiveField(2)
  String operationType;

  @HiveField(3)
  String payloadJson;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  String status; // PENDING, SYNCING, COMPLETED, FAILED

  @HiveField(6)
  int retryCount;

  @HiveField(7)
  String? errorInformation;

  @HiveField(8)
  String? syncResultJson;

  SyncQueueEntry({
    required this.id,
    this.entityId,
    required this.operationType,
    required this.payloadJson,
    required this.createdAt,
    this.status = 'PENDING',
    this.retryCount = 0,
    this.errorInformation,
    this.syncResultJson,
  });

  Map<String, dynamic> get payload => jsonDecode(payloadJson);
  set payload(Map<String, dynamic> val) => payloadJson = jsonEncode(val);

  Map<String, dynamic>? get syncResult =>
      syncResultJson != null ? jsonDecode(syncResultJson!) : null;
  set syncResult(Map<String, dynamic>? val) =>
      syncResultJson = val != null ? jsonEncode(val) : null;
}
