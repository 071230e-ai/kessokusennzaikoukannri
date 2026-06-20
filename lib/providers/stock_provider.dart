import 'package:flutter/foundation.dart';
import '../models/stock_item.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../services/api_client.dart';

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

  /// category|spec → 表示順
  final Map<String, int> _itemOrderMap = {};

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  // 公開ゲッター（旧API互換）
  List<StockItem> get stockItems => List.unmodifiable(_stockItems);
  List<DeliveryRecord> get deliveryRecords => List.unmodifiable(_deliveryRecords);
  List<ShippingRecord> get shippingRecords => List.unmodifiable(_shippingRecords);

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
      ]);
      final stocksJson = (results[0]['stocks'] as List?) ?? [];
      final delsJson = (results[1]['deliveries'] as List?) ?? [];
      final shpsJson = (results[2]['shipments'] as List?) ?? [];

      _stockItems = stocksJson
          .map((r) => StockItem.fromStockRow(r as Map<String, dynamic>))
          .toList();
      _deliveryRecords = delsJson
          .map((r) => DeliveryRecord.fromApi(r as Map<String, dynamic>))
          .toList();
      _shippingRecords = shpsJson
          .map((r) => ShippingRecord.fromApi(r as Map<String, dynamic>))
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
