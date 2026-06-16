// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockItemAdapter extends TypeAdapter<StockItem> {
  @override
  final int typeId = 0;

  @override
  StockItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockItem(
      id: fields[0] as String,
      category: fields[1] as String,
      spec: fields[2] as String,
      unit: fields[3] as String,
      currentStock: fields[4] as double,
      initialStock: fields[5] as double,
      lowStockThreshold: fields[6] as double,
      note: fields[7] as String?,
      lastDeliveryDate: fields[8] as DateTime?,
      lastShippingDate: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, StockItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.spec)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.currentStock)
      ..writeByte(5)
      ..write(obj.initialStock)
      ..writeByte(6)
      ..write(obj.lowStockThreshold)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.lastDeliveryDate)
      ..writeByte(9)
      ..write(obj.lastShippingDate);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
