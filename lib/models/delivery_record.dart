class DeliveryRecord {
  final String id;
  final int itemId;
  final int locationId;

  /// 互換性のため。`<itemId>_<locationId>` を入れる。
  final String stockItemId;
  final String category;
  final String spec;
  final String unit;
  final DateTime deliveryDate;
  final double quantity;
  final String? supplier;
  final String? staff;
  final String? note;
  final String location;

  DeliveryRecord({
    required this.id,
    required this.itemId,
    required this.locationId,
    required this.stockItemId,
    required this.category,
    required this.spec,
    required this.unit,
    required this.deliveryDate,
    required this.quantity,
    this.supplier,
    this.staff,
    this.note,
    this.location = '本社工場',
  });

  factory DeliveryRecord.fromApi(Map<String, dynamic> r) {
    final itemId = (r['item_id'] as num).toInt();
    final locId = (r['location_id'] as num).toInt();
    return DeliveryRecord(
      id: r['id'] as String,
      itemId: itemId,
      locationId: locId,
      stockItemId: '${itemId}_$locId',
      category: r['category'] as String,
      spec: r['spec'] as String,
      unit: r['unit'] as String,
      deliveryDate: DateTime.parse(r['delivery_date'] as String),
      quantity: (r['quantity'] as num).toDouble(),
      supplier: r['supplier'] as String?,
      staff: r['staff'] as String?,
      note: r['note'] as String?,
      location: r['location'] as String,
    );
  }
}
