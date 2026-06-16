/// 在庫品目 + 場所ペアごとのサマリ。
///
/// D1 上では `items` × `locations` のクロス結合に
/// `initial_stocks`/`delivery_records`/`shipping_records` を結合して算出する。
/// アプリ内では従来通り「品目×場所」を1単位として扱うため、互換性のために
/// このクラスをそのまま残し、Hive依存だけ取り除いている。
class StockItem {
  /// クライアント上の安定ID。`<item_id>_<location_id>` 形式を用いる。
  final String id;
  final int itemId;
  final int locationId;

  final String category;
  final String spec;
  final String unit;
  double currentStock;
  double initialStock;
  final double lowStockThreshold;
  String? note;
  DateTime? lastDeliveryDate;
  DateTime? lastShippingDate;
  final String location;

  StockItem({
    required this.id,
    required this.itemId,
    required this.locationId,
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

  /// /api/stocks の1行から構築する。
  factory StockItem.fromStockRow(Map<String, dynamic> r) {
    final itemId = (r['item_id'] as num).toInt();
    final locId = (r['location_id'] as num).toInt();
    return StockItem(
      id: '${itemId}_$locId',
      itemId: itemId,
      locationId: locId,
      category: r['category'] as String,
      spec: r['spec'] as String,
      unit: r['unit'] as String,
      currentStock: (r['current_stock'] as num).toDouble(),
      initialStock: (r['initial_stock'] as num).toDouble(),
      lowStockThreshold: (r['low_stock_threshold'] as num).toDouble(),
      note: (r['note'] as String?)?.isEmpty == true ? null : r['note'] as String?,
      location: r['location'] as String,
    );
  }
}
