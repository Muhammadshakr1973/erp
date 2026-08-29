// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueEntryAdapter extends TypeAdapter<SyncQueueEntry> {
  @override
  final int typeId = 0;

  @override
  SyncQueueEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueueEntry(
      id: fields[0] as String,
      entityId: fields[1] as String?,
      operationType: fields[2] as String,
      payloadJson: fields[3] as String,
      createdAt: fields[4] as DateTime,
      status: fields[5] as String,
      retryCount: fields[6] as int,
      errorInformation: fields[7] as String?,
      syncResultJson: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityId)
      ..writeByte(2)
      ..write(obj.operationType)
      ..writeByte(3)
      ..write(obj.payloadJson)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.retryCount)
      ..writeByte(7)
      ..write(obj.errorInformation)
      ..writeByte(8)
      ..write(obj.syncResultJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
