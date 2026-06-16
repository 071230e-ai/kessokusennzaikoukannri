// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryRecordAdapter extends TypeAdapter<DeliveryRecord> {
  @override
  final int typeId = 1;

  @override
  DeliveryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryRecord(
      id: fields[0] as String,
      stockItemId: fields[1] as String,
      category: fields[2] as String,
      spec: fields[3] as String,
      unit: fields[4] as String,
      deliveryDate: fields[5] as DateTime,
      quantity: fields[6] as double,
      supplier: fields[7] as String?,
      staff: fields[8] as String?,
      note: fields[9] as String?,
      // 旧データで location 未設定の場合は '本社工場' として扱う
      location: (fields[10] as String?) ?? '本社工場',
    );
  }

  @override
  void write(BinaryWriter writer, DeliveryRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.stockItemId)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.spec)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.deliveryDate)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.supplier)
      ..writeByte(8)
      ..write(obj.staff)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.location);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
