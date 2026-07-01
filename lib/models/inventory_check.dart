/// 月次の実在庫確認（照合）レコード。
///
/// サーバ側 inventory_checks テーブルと 1:1。
/// 「DBに行が存在する＝その月・その工場の確認が完了」というシンプルな表現。
/// 未完了は単に行が無いだけ（クライアント側で算出）。
class InventoryCheck {
  final int id;
  final int targetYear;
  final int targetMonth;
  final int locationId;
  final String location;
  final String status; // 通常 'completed'
  final DateTime? checkedAt;
  final String? checkedBy;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InventoryCheck({
    required this.id,
    required this.targetYear,
    required this.targetMonth,
    required this.locationId,
    required this.location,
    required this.status,
    this.checkedAt,
    this.checkedBy,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryCheck.fromApi(Map<String, dynamic> r) {
    DateTime? parseNullable(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    return InventoryCheck(
      id: (r['id'] as num).toInt(),
      targetYear: (r['target_year'] as num).toInt(),
      targetMonth: (r['target_month'] as num).toInt(),
      locationId: (r['location_id'] as num).toInt(),
      location: r['location'] as String,
      status: (r['status'] as String?) ?? 'completed',
      checkedAt: parseNullable(r['checked_at']),
      checkedBy: r['checked_by'] as String?,
      note: r['note'] as String?,
      createdAt: parseNullable(r['created_at']),
      updatedAt: parseNullable(r['updated_at']),
    );
  }

  bool get isCompleted => status == 'completed';
}
