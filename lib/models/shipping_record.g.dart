// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shipping_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShippingRecordAdapter extends TypeAdapter<ShippingRecord> {
  @override
  final int typeId = 2;

  @override
  ShippingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShippingRecord(
      id: fields[0] as String,
      stockItemId: fields[1] as String,
      category: fields[2] as String,
      spec: fields[3] as String,
      unit: fields[4] as String,
      shippingDate: fields[5] as DateTime,
      quantity: fields[6] as double,
      destination: fields[7] as String?,
      staff: fields[8] as String?,
      note: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShippingRecord obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.shippingDate)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.destination)
      ..writeByte(8)
      ..write(obj.staff)
      ..writeByte(9)
      ..write(obj.note);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShippingRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
