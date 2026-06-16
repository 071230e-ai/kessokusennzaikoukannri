import 'package:hive/hive.dart';

part 'stock_item.g.dart';

@HiveType(typeId: 0)
class StockItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String category; // 結束線, 18番結束線, タイワイヤ

  @HiveField(2)
  String spec; // 350mm, 400mm, ... or "-"

  @HiveField(3)
  String unit; // kg or 箱

  @HiveField(4)
  double currentStock;

  @HiveField(5)
  double initialStock;

  @HiveField(6)
  double lowStockThreshold;

  @HiveField(7)
  String? note;

  @HiveField(8)
  DateTime? lastDeliveryDate;

  @HiveField(9)
  DateTime? lastShippingDate;

  /// 保管場所（'本社工場' / '第二工場'）。
  /// 旧データで未設定の場合は '本社工場' として扱う。
  @HiveField(10)
  String location;

  StockItem({
    required this.id,
    required this.category,
    required this.spec,
    required this.unit,
    this.currentStock = 0,
    this.initialStock = 0,
    this.lowStockThreshold = 20,
    this.note,
    this.lastDeliveryDate,
    this.lastShippingDate,
    this.location = '本社工場',
  });

  String get displayName => spec == '-' ? category : '$category $spec';
}
