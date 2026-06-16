class ShippingRecord {
  final String id;
  final int itemId;
  final int locationId;

  final String stockItemId;
  final String category;
  final String spec;
  final String unit;
  final DateTime shippingDate;
  final double quantity;
  final String? destination;
  final String? staff;
  final String? note;
  final String location;

  ShippingRecord({
    required this.id,
    required this.itemId,
    required this.locationId,
    required this.stockItemId,
    required this.category,
    required this.spec,
    required this.unit,
    required this.shippingDate,
    required this.quantity,
    this.destination,
    this.staff,
    this.note,
    this.location = '本社工場',
  });

  factory ShippingRecord.fromApi(Map<String, dynamic> r) {
    final itemId = (r['item_id'] as num).toInt();
    final locId = (r['location_id'] as num).toInt();
    return ShippingRecord(
      id: r['id'] as String,
      itemId: itemId,
      locationId: locId,
      stockItemId: '${itemId}_$locId',
      category: r['category'] as String,
      spec: r['spec'] as String,
      unit: r['unit'] as String,
      shippingDate: DateTime.parse(r['shipping_date'] as String),
      quantity: (r['quantity'] as num).toDouble(),
      destination: r['destination'] as String?,
      staff: r['staff'] as String?,
      note: r['note'] as String?,
      location: r['location'] as String,
    );
  }
}
