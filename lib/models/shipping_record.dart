import 'package:hive/hive.dart';

part 'shipping_record.g.dart';

@HiveType(typeId: 2)
class ShippingRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String stockItemId;

  @HiveField(2)
  String category;

  @HiveField(3)
  String spec;

  @HiveField(4)
  String unit;

  @HiveField(5)
  DateTime shippingDate;

  @HiveField(6)
  double quantity;

  @HiveField(7)
  String? destination; // 出荷先・使用場所

  @HiveField(8)
  String? staff; // 担当者

  @HiveField(9)
  String? note;

  ShippingRecord({
    required this.id,
    required this.stockItemId,
    required this.category,
    required this.spec,
    required this.unit,
    required this.shippingDate,
    required this.quantity,
    this.destination,
    this.staff,
    this.note,
  });
}
