/// 在庫修正レコード。
///
/// D1 テーブル `stock_adjustments` の1行を表す。
/// 一括修正時は同じ `adjustmentGroupId` を共有する。
class StockAdjustment {
  final int id;
  final String adjustmentGroupId;
  final int locationId;
  final String location;
  final int itemId;
  final String category;
  final String spec;
  final String unit;
  final double previousStock;
  final double adjustedStock;
  final double difference;

  /// 修正日時（JST +09:00 の DateTime。fromApi では UTC の DateTime として保持し、
  /// 表示側で JstTime.formatDisplay に渡す）。
  final DateTime adjustedAt;

  final String? adjustedBy;
  final String? note;
  final DateTime? createdAt;

  StockAdjustment({
    required this.id,
    required this.adjustmentGroupId,
    required this.locationId,
    required this.location,
    required this.itemId,
    required this.category,
    required this.spec,
    required this.unit,
    required this.previousStock,
    required this.adjustedStock,
    required this.difference,
    required this.adjustedAt,
    this.adjustedBy,
    this.note,
    this.createdAt,
  });

  String get displayName => spec == '-' ? category : '$category $spec';

  factory StockAdjustment.fromApi(Map<String, dynamic> r) {
    return StockAdjustment(
      id: (r['id'] as num).toInt(),
      adjustmentGroupId: r['adjustment_group_id'] as String? ?? '',
      locationId: (r['location_id'] as num).toInt(),
      location: r['location'] as String? ?? '',
      itemId: (r['item_id'] as num).toInt(),
      category: r['category'] as String? ?? '',
      spec: r['spec'] as String? ?? '',
      unit: r['unit'] as String? ?? '',
      previousStock: (r['previous_stock'] as num?)?.toDouble() ?? 0,
      adjustedStock: (r['adjusted_stock'] as num?)?.toDouble() ?? 0,
      difference: (r['difference'] as num?)?.toDouble() ?? 0,
      adjustedAt: _parseDate(r['adjusted_at']) ?? DateTime.now().toUtc(),
      adjustedBy: (r['adjusted_by'] as String?)?.isEmpty == true
          ? null
          : r['adjusted_by'] as String?,
      note: (r['note'] as String?)?.isEmpty == true
          ? null
          : r['note'] as String?,
      createdAt: _parseDate(r['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    // '+09:00' が付いていれば DateTime.parse で正しく解釈される。
    // 付いていない (created_at = SQLite datetime('now') の 'YYYY-MM-DD HH:MM:SS' 形式) 場合は
    // UTC として解釈する。
    try {
      if (s.contains('T') || s.endsWith('Z') || s.contains('+') || s.contains('-', 10)) {
        return DateTime.parse(s);
      }
      // 'YYYY-MM-DD HH:MM:SS' → UTC
      return DateTime.parse('${s.replaceFirst(' ', 'T')}Z');
    } catch (_) {
      return null;
    }
  }
}
