import 'package:flutter/foundation.dart';
import '../models/stock_item.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../models/inventory_check.dart';
import '../models/stock_adjustment.dart';
import '../services/api_client.dart';
import '../utils/jst_time.dart';

/// Cloudflare D1（Pages Functions API）ベースの在庫プロバイダ。
///
/// 公開API（プロパティ・メソッド名）は旧 Hive 実装と互換性を保つ。
/// 内部で `/api/stocks` `/api/deliveries` `/api/shipments` を呼び出し、
/// メモリ上にキャッシュ → mutation のたびにサーバから再取得する。
class StockProvider extends ChangeNotifier {
  // =====================================================================
  // 定数
  // =====================================================================
  // (旧 Hive 互換用に残す。新実装では未使用)
  static const String stockBoxName = 'stock_items';
  static const String deliveryBoxName = 'delivery_records';
  static const String shippingBoxName = 'shipping_records';

  static const String locationHonsha = '本社工場';
  static const String locationDaini = '第二工場';
  static const List<String> locations = [locationHonsha, locationDaini];

  // =====================================================================
  // 状態
  // =====================================================================
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _lastError;

  List<StockItem> _stockItems = [];
  List<DeliveryRecord> _deliveryRecords = [];
  List<ShippingRecord> _shippingRecords = [];
  List<InventoryCheck> _inventoryChecks = [];
  List<StockAdjustment> _stockAdjustments = [];

  /// category|spec → 表示順
  final Map<String, int> _itemOrderMap = {};

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  // 公開ゲッター（旧API互換）
  List<StockItem> get stockItems => List.unmodifiable(_stockItems);
  List<DeliveryRecord> get deliveryRecords => List.unmodifiable(_deliveryRecords);
  List<ShippingRecord> get shippingRecords => List.unmodifiable(_shippingRecords);
  List<InventoryCheck> get inventoryChecks => List.unmodifiable(_inventoryChecks);
  List<StockAdjustment> get stockAdjustments => List.unmodifiable(_stockAdjustments);

  // =====================================================================
  // 初期化／リロード
  // =====================================================================

  Future<void> initialize() async {
    await refreshAll();
    _isInitialized = true;
    notifyListeners();
  }

  /// 全データをサーバから再取得する。
  Future<void> refreshAll() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      // 並列に取得
      final results = await Future.wait([
        ApiClient.getJson('/api/stocks'),
        ApiClient.getJson('/api/deliveries'),
        ApiClient.getJson('/api/shipments'),
        ApiClient.getJson('/api/inventory-checks'),
        ApiClient.getJson('/api/stock-adjustments'),
      ]);
      final stocksJson = (results[0]['stocks'] as List?) ?? [];
      final delsJson = (results[1]['deliveries'] as List?) ?? [];
      final shpsJson = (results[2]['shipments'] as List?) ?? [];
      final checksJson = (results[3]['checks'] as List?) ?? [];
      final adjsJson = (results[4]['adjustments'] as List?) ?? [];

      _stockItems = stocksJson
          .map((r) => StockItem.fromStockRow(r as Map<String, dynamic>))
          .toList();
      _deliveryRecords = delsJson
          .map((r) => DeliveryRecord.fromApi(r as Map<String, dynamic>))
          .toList();
      _shippingRecords = shpsJson
          .map((r) => ShippingRecord.fromApi(r as Map<String, dynamic>))
          .toList();
      _inventoryChecks = checksJson
          .map((r) => InventoryCheck.fromApi(r as Map<String, dynamic>))
          .toList();
      _stockAdjustments = adjsJson
          .map((r) => StockAdjustment.fromApi(r as Map<String, dynamic>))
          .toList();

      // 表示順マップを再構築（/api/stocks の並びをそのまま採用）
      _itemOrderMap.clear();
      int idx = 0;
      for (final s in _stockItems) {
        final key = '${s.category}|${s.spec}';
        _itemOrderMap.putIfAbsent(key, () => idx++);
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[StockProvider] refresh error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================================
  // 初期在庫の更新
  // =====================================================================

  /// 単一品目の初期在庫を更新（旧API互換 stockItemId は `<itemId>_<locId>`）
  Future<void> updateInitialStock(String stockItemId, double newInitialStock) async {
    final item = getStockItem(stockItemId);
    if (item == null) return;
    await ApiClient.postJson('/api/initial-stock', {
      'item_id': item.itemId,
      'location_id': item.locationId,
      'initial_stock': newInitialStock,
      'note': item.note,
    });
    await refreshAll();
  }

  /// 複数品目の初期在庫を一括更新
  Future<void> updateAllInitialStocks(Map<String, double> updates) async {
    for (final entry in updates.entries) {
      final item = getStockItem(entry.key);
      if (item == null) continue;
      await ApiClient.postJson('/api/initial-stock', {
        'item_id': item.itemId,
        'location_id': item.locationId,
        'initial_stock': entry.value,
        'note': item.note,
      });
    }
    await refreshAll();
  }

  // =====================================================================
  // 在庫修正（stock_adjustments）
  // =====================================================================

  /// 指定工場の複数品目を1リクエストで一括修正する。
  ///
  /// [items] は `(stockItemId, adjustedStock)` のリスト。
  /// stockItemId は `<itemId>_<locId>` 形式（StockItem.id）。
  /// サーバ側で D1 batch により atomic に書き込まれる。
  ///
  /// 戻り値は `{ok, adjustment_group_id, count}`。
  /// 失敗時は ApiException を投げる（呼び出し側でハンドリング）。
  Future<Map<String, dynamic>> saveBulkAdjustments({
    required String locationName,
    required List<({String stockItemId, double adjustedStock})> items,
    String? adjustedBy,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('items is empty');
    }
    // location_id を解決
    final anyStock = _stockItems.firstWhere(
      (s) => s.location == locationName,
      orElse: () => throw StateError('location not found: $locationName'),
    );
    final locationId = anyStock.locationId;

    // 各品目の previous_stock（現在庫）と item_id を解決
    final payloadItems = <Map<String, dynamic>>[];
    for (final e in items) {
      final s = getStockItem(e.stockItemId);
      if (s == null) {
        throw StateError('stock item not found: ${e.stockItemId}');
      }
      if (s.location != locationName) {
        throw StateError(
          'location mismatch: ${e.stockItemId} is ${s.location}, expected $locationName',
        );
      }
      payloadItems.add({
        'item_id': s.itemId,
        'previous_stock': s.currentStock,
        'adjusted_stock': e.adjustedStock,
      });
    }

    final nowJst = JstTime.now();
    final res = await ApiClient.postJson('/api/stock-adjustments', {
      'location_id': locationId,
      'adjusted_at': JstTime.formatIso(nowJst),
      'adjusted_by': adjustedBy,
      'note': note,
      'items': payloadItems,
    });
    await refreshAll();
    return res;
  }

  /// 特定 (item, location) の最新の在庫修正を取得（未修正なら null）。
  StockAdjustment? getLatestAdjustment({
    required int itemId,
    required int locationId,
  }) {
    StockAdjustment? latest;
    for (final a in _stockAdjustments) {
      if (a.itemId != itemId || a.locationId != locationId) continue;
      if (latest == null || a.adjustedAt.isAfter(latest.adjustedAt)) {
        latest = a;
      }
    }
    return latest;
  }

  /// 特定 (item, location) の在庫修正履歴（新しい順）
  List<StockAdjustment> getAdjustmentsForItem({
    required int itemId,
    required int locationId,
  }) {
    final list = _stockAdjustments
        .where((a) => a.itemId == itemId && a.locationId == locationId)
        .toList();
    list.sort((a, b) => b.adjustedAt.compareTo(a.adjustedAt));
    return list;
  }

  // =====================================================================
  // 納入登録
  // =====================================================================

  Future<void> addDelivery({
    required String stockItemId,
    required DateTime deliveryDate,
    required double quantity,
    String? supplier,
    String? staff,
    String? note,
  }) async {
    final item = getStockItem(stockItemId);
    if (item == null) return;
    await ApiClient.postJson('/api/deliveries', {
      'item_id': item.itemId,
      'location_id': item.locationId,
      'delivery_date': _formatDate(deliveryDate),
      'quantity': quantity,
      'supplier': supplier,
      'staff': staff,
      'note': note,
    });
    await refreshAll();
  }

  // =====================================================================
  // 出荷・使用登録
  // =====================================================================

  /// 在庫不足の場合は false を返す。
  Future<bool> addShipping({
    required String stockItemId,
    required DateTime shippingDate,
    required double quantity,
    String? destination,
    String? staff,
    String? note,
  }) async {
    final item = getStockItem(stockItemId);
    if (item == null) return false;
    if (quantity > item.currentStock) return false;
    try {
      await ApiClient.postJson('/api/shipments', {
        'item_id': item.itemId,
        'location_id': item.locationId,
        'shipping_date': _formatDate(shippingDate),
        'quantity': quantity,
        'destination': destination,
        'staff': staff,
        'note': note,
      });
    } on ApiException catch (e) {
      if (e.status == 409) {
        await refreshAll();
        return false;
      }
      rethrow;
    }
    await refreshAll();
    return true;
  }

  // =====================================================================
  // 履歴更新
  // =====================================================================

  /// 納入履歴の更新。
  /// 在庫数は GET /api/stocks が都度計算するため、ここでは
  /// PUT 後に refreshAll() を呼ぶだけで在庫が正しく再計算される。
  Future<void> updateDelivery({
    required String recordId,
    required String stockItemId,
    required DateTime deliveryDate,
    required double quantity,
    String? supplier,
    String? staff,
    String? note,
  }) async {
    final item = getStockItem(stockItemId);
    if (item == null) return;
    await ApiClient.putJson('/api/deliveries/$recordId', {
      'item_id': item.itemId,
      'location_id': item.locationId,
      'delivery_date': _formatDate(deliveryDate),
      'quantity': quantity,
      'supplier': supplier,
      'staff': staff,
      'note': note,
    });
    await refreshAll();
  }

  /// 出荷・使用履歴の更新。
  /// 在庫不足の場合は false を返す（変更前の数量を一度戻した状態でサーバ側がチェック）。
  Future<bool> updateShipping({
    required String recordId,
    required String stockItemId,
    required DateTime shippingDate,
    required double quantity,
    String? destination,
    String? staff,
    String? note,
  }) async {
    final item = getStockItem(stockItemId);
    if (item == null) return false;
    try {
      await ApiClient.putJson('/api/shipments/$recordId', {
        'item_id': item.itemId,
        'location_id': item.locationId,
        'shipping_date': _formatDate(shippingDate),
        'quantity': quantity,
        'destination': destination,
        'staff': staff,
        'note': note,
      });
    } on ApiException catch (e) {
      if (e.status == 409) {
        await refreshAll();
        return false;
      }
      rethrow;
    }
    await refreshAll();
    return true;
  }

  // =====================================================================
  // 履歴削除
  // =====================================================================

  Future<void> deleteDelivery(String recordId) async {
    await ApiClient.delete('/api/deliveries/$recordId');
    await refreshAll();
  }

  Future<void> deleteShipping(String recordId) async {
    await ApiClient.delete('/api/shipments/$recordId');
    await refreshAll();
  }

  // =====================================================================
  // 在庫確認（実在庫照合）
  // =====================================================================

  /// 当月 (JST) の確認を完了登録する。
  ///
  /// [locationName] は '本社工場' または '第二工場'。
  /// サーバ側で UNIQUE(year, month, location_id) なので同月の重複は upsert される。
  Future<bool> markInventoryCheckCompleted({
    required int year,
    required int month,
    required String locationName,
    String? checkedBy,
    String? note,
  }) async {
    // location_id を在庫データから解決（locations マスタの id）
    final loc = _stockItems.firstWhere(
      (s) => s.location == locationName,
      orElse: () => throw StateError('location not found: $locationName'),
    );
    final nowJst = JstTime.now();
    await ApiClient.postJson('/api/inventory-checks', {
      'target_year': year,
      'target_month': month,
      'location_id': loc.locationId,
      'checked_at': JstTime.formatIso(nowJst),
      'checked_by': checkedBy,
      'note': note,
    });
    await refreshAll();
    return true;
  }

  /// 在庫確認の完了状態を取り消す（DBから行を削除）。
  /// → 当月分の場合、通知が再表示される。
  Future<void> revokeInventoryCheck(int recordId) async {
    await ApiClient.delete('/api/inventory-checks/$recordId');
    await refreshAll();
  }

  /// 当月 (JST) 内で未完了の工場名一覧を返す。
  /// 「毎月1日以降の未完了通知」表示判定に使う。
  List<String> getCurrentMonthUncompletedLocations() {
    final (year, month) = JstTime.currentYearMonth();
    final completed = _inventoryChecks
        .where((c) => c.targetYear == year && c.targetMonth == month)
        .map((c) => c.location)
        .toSet();
    return locations.where((loc) => !completed.contains(loc)).toList();
  }

  /// 当月 (JST) の各工場の確認状態を返す。
  /// 戻り値は location → InventoryCheck?（null は未完了）。
  Map<String, InventoryCheck?> getCurrentMonthCheckStatus() {
    final (year, month) = JstTime.currentYearMonth();
    final byLoc = <String, InventoryCheck?>{};
    for (final loc in locations) {
      byLoc[loc] = _inventoryChecks
          .where((c) =>
              c.targetYear == year &&
              c.targetMonth == month &&
              c.location == loc)
          .cast<InventoryCheck?>()
          .firstWhere((_) => true, orElse: () => null);
    }
    return byLoc;
  }

  /// 過去月（当月より前）で未完了の工場・年月の組み合わせを返す。
  /// 過去月で完了した行が無いものを「未完了」とみなす。
  /// 対象期間は inventory_checks にレコードが1件でも存在する最古の年月〜先月。
  /// レコードが無い場合は空配列を返す（運用開始前の過去月は遡らない）。
  List<({int year, int month, String location})> getPastUncompleted() {
    if (_inventoryChecks.isEmpty) return [];
    final (curY, curM) = JstTime.currentYearMonth();

    // 当月より過去の最古の年月を取得
    final pastRecords = _inventoryChecks.where((c) {
      if (c.targetYear < curY) return true;
      if (c.targetYear == curY && c.targetMonth < curM) return true;
      return false;
    }).toList();
    if (pastRecords.isEmpty) return [];

    int oldestY = curY, oldestM = curM;
    for (final r in pastRecords) {
      if (r.targetYear < oldestY ||
          (r.targetYear == oldestY && r.targetMonth < oldestM)) {
        oldestY = r.targetYear;
        oldestM = r.targetMonth;
      }
    }

    // oldestY/M〜先月 までを走査し、各 (year, month, location) で完了行が無いものを集める
    final completedSet = <String>{};
    for (final c in _inventoryChecks) {
      completedSet.add('${c.targetYear}|${c.targetMonth}|${c.location}');
    }

    final result = <({int year, int month, String location})>[];
    int y = oldestY;
    int m = oldestM;
    while (y < curY || (y == curY && m < curM)) {
      for (final loc in locations) {
        if (!completedSet.contains('$y|$m|$loc')) {
          result.add((year: y, month: m, location: loc));
        }
      }
      m += 1;
      if (m > 12) {
        m = 1;
        y += 1;
      }
    }
    return result;
  }

  /// 「2026年7月 本社工場」のレコードを取得（無ければ null）
  InventoryCheck? findCheck({
    required int year,
    required int month,
    required String locationName,
  }) {
    for (final c in _inventoryChecks) {
      if (c.targetYear == year &&
          c.targetMonth == month &&
          c.location == locationName) {
        return c;
      }
    }
    return null;
  }

  // =====================================================================
  // 備考更新
  // =====================================================================

  /// initial_stocks.note を更新する。
  Future<void> updateNote(String stockItemId, String? note) async {
    final item = getStockItem(stockItemId);
    if (item == null) return;
    await ApiClient.postJson('/api/initial-stock', {
      'item_id': item.itemId,
      'location_id': item.locationId,
      'initial_stock': item.initialStock,
      'note': note,
    });
    await refreshAll();
  }

  // =====================================================================
  // ゲッター・フィルター（旧API互換）
  // =====================================================================

  StockItem? getStockItem(String id) {
    for (final s in _stockItems) {
      if (s.id == id) return s;
    }
    return null;
  }

  StockItem? findStockItem({
    required String category,
    required String spec,
    required String location,
  }) {
    for (final i in _stockItems) {
      if (i.category == category && i.spec == spec && i.location == location) {
        return i;
      }
    }
    return null;
  }

  /// 定義順のカテゴリ一覧（重複なし）
  List<String> get categories {
    final seen = <String>{};
    final result = <String>[];
    for (final s in _stockItems) {
      if (seen.add(s.category)) result.add(s.category);
    }
    return result;
  }

  /// 指定カテゴリの規格一覧（表示順）
  List<String> getSpecsForCategory(String category) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in _stockItems) {
      if (s.category != category) continue;
      if (seen.add(s.spec)) result.add(s.spec);
    }
    return result;
  }

  /// 「カテゴリ＋規格」ユニークなペア（表示順）
  List<Map<String, String>> get itemPairs {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final s in _stockItems) {
      final key = '${s.category}|${s.spec}';
      if (seen.add(key)) {
        result.add({'category': s.category, 'spec': s.spec});
      }
    }
    return result;
  }

  /// 指定場所の在庫項目（表示順）
  List<StockItem> getStockItemsByLocation(String location) {
    return _stockItems.where((i) => i.location == location).toList();
  }

  /// 在庫一覧サマリー（品目別 × 本社/第二/合計）
  List<StockSummary> get stockSummaries {
    final list = <StockSummary>[];
    for (final pair in itemPairs) {
      final cat = pair['category']!;
      final spec = pair['spec']!;
      final honsha =
          findStockItem(category: cat, spec: spec, location: locationHonsha);
      final daini =
          findStockItem(category: cat, spec: spec, location: locationDaini);
      final unit = honsha?.unit ?? daini?.unit ?? 'kg';
      final threshold =
          honsha?.lowStockThreshold ?? daini?.lowStockThreshold ?? 20;
      list.add(StockSummary(
        category: cat,
        spec: spec,
        unit: unit,
        lowStockThreshold: threshold,
        honshaItem: honsha,
        dainiItem: daini,
      ));
    }
    return list;
  }

  List<StockItem> getFilteredStockItems({
    String? category,
    String? spec,
    String? location,
    String? sortBy,
  }) {
    var items = _stockItems.toList();
    if (category != null && category.isNotEmpty) {
      items = items.where((i) => i.category == category).toList();
    }
    if (spec != null && spec.isNotEmpty) {
      items = items.where((i) => i.spec == spec).toList();
    }
    if (location != null && location.isNotEmpty) {
      items = items.where((i) => i.location == location).toList();
    }
    if (sortBy == 'stock_asc') {
      items.sort((a, b) => a.currentStock.compareTo(b.currentStock));
    } else if (sortBy == 'stock_desc') {
      items.sort((a, b) => b.currentStock.compareTo(a.currentStock));
    }
    return items;
  }

  List<DeliveryRecord> getFilteredDeliveries({
    String? category,
    String? spec,
    String? location,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var records = _deliveryRecords.toList();
    if (category != null && category.isNotEmpty) {
      records = records.where((r) => r.category == category).toList();
    }
    if (spec != null && spec.isNotEmpty) {
      records = records.where((r) => r.spec == spec).toList();
    }
    if (location != null && location.isNotEmpty) {
      records = records.where((r) => r.location == location).toList();
    }
    if (fromDate != null) {
      records =
          records.where((r) => !r.deliveryDate.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final end = toDate.add(const Duration(days: 1));
      records = records.where((r) => r.deliveryDate.isBefore(end)).toList();
    }
    return records;
  }

  List<ShippingRecord> getFilteredShippings({
    String? category,
    String? spec,
    String? location,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var records = _shippingRecords.toList();
    if (category != null && category.isNotEmpty) {
      records = records.where((r) => r.category == category).toList();
    }
    if (spec != null && spec.isNotEmpty) {
      records = records.where((r) => r.spec == spec).toList();
    }
    if (location != null && location.isNotEmpty) {
      records = records.where((r) => r.location == location).toList();
    }
    if (fromDate != null) {
      records =
          records.where((r) => !r.shippingDate.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final end = toDate.add(const Duration(days: 1));
      records = records.where((r) => r.shippingDate.isBefore(end)).toList();
    }
    return records;
  }

  /// 低在庫品目（UIでは未使用だが計算ロジック維持のため残す）
  List<StockItem> get lowStockItems =>
      _stockItems.where((i) => i.currentStock <= i.lowStockThreshold).toList();

  // =====================================================================
  // ヘルパー
  // =====================================================================

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// 在庫一覧サマリー（旧API互換）
class StockSummary {
  final String category;
  final String spec;
  final String unit;
  final double lowStockThreshold;
  final StockItem? honshaItem;
  final StockItem? dainiItem;

  StockSummary({
    required this.category,
    required this.spec,
    required this.unit,
    required this.lowStockThreshold,
    required this.honshaItem,
    required this.dainiItem,
  });

  double get honshaStock => honshaItem?.currentStock ?? 0;
  double get dainiStock => dainiItem?.currentStock ?? 0;
  double get totalStock => honshaStock + dainiStock;

  double get honshaInitial => honshaItem?.initialStock ?? 0;
  double get dainiInitial => dainiItem?.initialStock ?? 0;
  double get totalInitial => honshaInitial + dainiInitial;

  bool get isLow =>
      (honshaItem != null && honshaItem!.currentStock <= lowStockThreshold) ||
      (dainiItem != null && dainiItem!.currentStock <= lowStockThreshold);

  String get displayName => spec == '-' ? category : '$category $spec';
}
