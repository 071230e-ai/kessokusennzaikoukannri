import 'package:hive/hive.dart';

part 'delivery_record.g.dart';

@HiveType(typeId: 1)
class DeliveryRecord extends HiveObject {
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
  DateTime deliveryDate;

  @HiveField(6)
  double quantity;

  @HiveField(7)
  String? supplier; // 仕入先

  @HiveField(8)
  String? staff; // 担当者

  @HiveField(9)
  String? note;

  DeliveryRecord({
    required this.id,
    required this.stockItemId,
    required this.category,
    required this.spec,
    required this.unit,
    required this.deliveryDate,
    required this.quantity,
    this.supplier,
    this.staff,
    this.note,
  });
}
