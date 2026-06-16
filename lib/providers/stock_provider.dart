import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/stock_item.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';

class StockProvider extends ChangeNotifier {
  static const String stockBoxName = 'stock_items';
  static const String deliveryBoxName = 'delivery_records';
  static const String shippingBoxName = 'shipping_records';

  // ---- 保管場所定数 ----
  static const String locationHonsha = '本社工場';
  static const String locationDaini = '第二工場';
  static const List<String> locations = [locationHonsha, locationDaini];

  late Box<StockItem> _stockBox;
  late Box<DeliveryRecord> _deliveryBox;
  late Box<ShippingRecord> _shippingBox;

  final _uuid = const Uuid();

  // --- 品目の正規の並び順（カテゴリ・規格の定義順） ---
  static const List<Map<String, String>> _itemOrder = [
    {'category': '結束線', 'spec': '350mm'},
    {'category': '結束線', 'spec': '400mm'},
    {'category': '結束線', 'spec': '450mm'},
    {'category': '結束線', 'spec': '500mm'},
    {'category': '結束線', 'spec': '550mm'},
    {'category': '結束線', 'spec': '600mm'},
    {'category': '結束線', 'spec': '650mm'},
    {'category': '結束線', 'spec': '700mm'},
    {'category': 'メッキ結束線', 'spec': '350mm'},
    {'category': 'メッキ結束線', 'spec': '400mm'},
    {'category': 'メッキ結束線', 'spec': '450mm'},
    {'category': 'メッキ結束線', 'spec': '500mm'},
    {'category': 'メッキ結束線', 'spec': '550mm'},
    {'category': 'メッキ結束線', 'spec': '600mm'},
    {'category': 'メッキ結束線', 'spec': '650mm'},
    {'category': 'メッキ結束線', 'spec': '700mm'},
    {'category': '18番結束線', 'spec': '550mm'},
    {'category': '18番結束線', 'spec': '700mm'},
    {'category': 'タイワイヤ', 'spec': '-'},
  ];

  /// 品目の定義順インデックスを返す
  int _itemSortIndex(String category, String spec) {
    for (int i = 0; i < _itemOrder.length; i++) {
      if (_itemOrder[i]['category'] == category &&
          _itemOrder[i]['spec'] == spec) {
        return i;
      }
    }
    return _itemOrder.length;
  }

  /// 場所の並び順インデックス（本社→第二）
  int _locationSortIndex(String location) {
    final i = locations.indexOf(location);
    return i < 0 ? locations.length : i;
  }

  /// 定義順（品目→場所）にソートされた全在庫リスト
  List<StockItem> get stockItems {
    final list = _stockBox.values.toList();
    list.sort((a, b) {
      final c = _itemSortIndex(a.category, a.spec)
          .compareTo(_itemSortIndex(b.category, b.spec));
      if (c != 0) return c;
      return _locationSortIndex(a.location)
          .compareTo(_locationSortIndex(b.location));
    });
    return list;
  }

  List<DeliveryRecord> get deliveryRecords =>
      _deliveryBox.values.toList()
        ..sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));

  List<ShippingRecord> get shippingRecords =>
      _shippingBox.values.toList()
        ..sort((a, b) => b.shippingDate.compareTo(a.shippingDate));

  Future<void> initialize() async {
    _stockBox = Hive.box<StockItem>(stockBoxName);
    _deliveryBox = Hive.box<DeliveryRecord>(deliveryBoxName);
    _shippingBox = Hive.box<ShippingRecord>(shippingBoxName);

    if (_stockBox.isEmpty) {
      await _initializeDefaultItems();
    } else {
      // 既存ユーザー向け：定義に存在しない品目・場所だけを追加
      await _ensureMasterItems();
    }

    // 既存データの単位マイグレーション（タイワイヤ：箱 → 個）
    // 数量は変更せず、表示単位のみ更新する。
    await _migrateTaiwireUnit();
  }

  /// タイワイヤの単位を「箱」から「個」へ更新するマイグレーション。
  /// 既存の数量・履歴は変更しない。すでに「個」のレコードはスキップ。
  Future<void> _migrateTaiwireUnit() async {
    // 在庫品目
    for (final item in _stockBox.values) {
      if (item.category == 'タイワイヤ' && item.unit == '箱') {
        item.unit = '個';
        await item.save();
      }
    }
    // 納入履歴
    for (final rec in _deliveryBox.values) {
      if (rec.category == 'タイワイヤ' && rec.unit == '箱') {
        rec.unit = '個';
        await rec.save();
      }
    }
    // 出荷・使用履歴
    for (final rec in _shippingBox.values) {
      if (rec.category == 'タイワイヤ' && rec.unit == '箱') {
        rec.unit = '個';
        await rec.save();
      }
    }
  }

  /// 全マスタ品目（カテゴリ・規格・単位・既定下限）の定義
  static const List<Map<String, dynamic>> _masterItemBase = [
    {'category': '結束線',      'spec': '350mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '400mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '450mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '500mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '550mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '600mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '650mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '結束線',      'spec': '700mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '350mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '400mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '450mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '500mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '550mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '600mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '650mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'メッキ結束線', 'spec': '700mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '18番結束線',  'spec': '550mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': '18番結束線',  'spec': '700mm', 'unit': 'kg', 'threshold': 20.0},
    {'category': 'タイワイヤ',   'spec': '-',     'unit': '個', 'threshold': 5.0},
  ];

  /// 新規ユーザー向け：全品目×全場所（19×2=38件）を作成
  Future<void> _initializeDefaultItems() async {
    for (final loc in locations) {
      for (final m in _masterItemBase) {
        final item = StockItem(
          id: _uuid.v4(),
          category: m['category'] as String,
          spec: m['spec'] as String,
          unit: m['unit'] as String,
          lowStockThreshold: m['threshold'] as double,
          location: loc,
        );
        await _stockBox.put(item.id, item);
      }
    }
  }

  /// 既存ボックス内に未登録のマスタ品目（カテゴリ＋規格＋場所）があれば追加。
  /// 既存データは一切変更しない。
  Future<void> _ensureMasterItems() async {
    final existingKeys = _stockBox.values
        .map((i) => '${i.category}|${i.spec}|${i.location}')
        .toSet();
    for (final loc in locations) {
      for (final m in _masterItemBase) {
        final key = '${m['category']}|${m['spec']}|$loc';
        if (existingKeys.contains(key)) continue;
        final item = StockItem(
          id: _uuid.v4(),
          category: m['category'] as String,
          spec: m['spec'] as String,
          unit: m['unit'] as String,
          lowStockThreshold: m['threshold'] as double,
          location: loc,
        );
        await _stockBox.put(item.id, item);
      }
    }
  }

  // =====================================================================
  // 初期在庫の更新
  // =====================================================================

  Future<void> updateInitialStock(String stockItemId, double newInitialStock) async {
    final item = _stockBox.get(stockItemId);
    if (item == null) return;
    item.initialStock = newInitialStock;
    await item.save();
    _recalculateStock(stockItemId);
    notifyListeners();
  }

  Future<void> updateAllInitialStocks(Map<String, double> updates) async {
    for (final entry in updates.entries) {
      final item = _stockBox.get(entry.key);
      if (item == null) continue;
      item.initialStock = entry.value;
      await item.save();
      _recalculateStock(entry.key);
    }
    notifyListeners();
  }

  // =====================================================================
  // 在庫再計算（保管場所別）
  // =====================================================================

  void _recalculateStock(String stockItemId) {
    final item = _stockBox.get(stockItemId);
    if (item == null) return;

    // この品目（カテゴリ＋規格＋場所）に紐づく履歴のみを集計
    final totalDelivery = _deliveryBox.values
        .where((r) =>
            r.category == item.category &&
            r.spec == item.spec &&
            r.location == item.location)
        .fold<double>(0, (sum, r) => sum + r.quantity);

    final totalShipping = _shippingBox.values
        .where((r) =>
            r.category == item.category &&
            r.spec == item.spec &&
            r.location == item.location)
        .fold<double>(0, (sum, r) => sum + r.quantity);

    item.currentStock = item.initialStock + totalDelivery - totalShipping;

    final deliveryList = _deliveryBox.values
        .where((r) =>
            r.category == item.category &&
            r.spec == item.spec &&
            r.location == item.location)
        .toList();
    if (deliveryList.isNotEmpty) {
      deliveryList.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
      item.lastDeliveryDate = deliveryList.first.deliveryDate;
    } else {
      item.lastDeliveryDate = null;
    }

    final shippingList = _shippingBox.values
        .where((r) =>
            r.category == item.category &&
            r.spec == item.spec &&
            r.location == item.location)
        .toList();
    if (shippingList.isNotEmpty) {
      shippingList.sort((a, b) => b.shippingDate.compareTo(a.shippingDate));
      item.lastShippingDate = shippingList.first.shippingDate;
    } else {
      item.lastShippingDate = null;
    }

    item.save();
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
    final item = _stockBox.get(stockItemId);
    if (item == null) return;

    final record = DeliveryRecord(
      id: _uuid.v4(),
      stockItemId: stockItemId,
      category: item.category,
      spec: item.spec,
      unit: item.unit,
      deliveryDate: deliveryDate,
      quantity: quantity,
      supplier: supplier,
      staff: staff,
      note: note,
      location: item.location,
    );

    await _deliveryBox.put(record.id, record);
    _recalculateStock(stockItemId);
    notifyListeners();
  }

  // =====================================================================
  // 出荷・使用登録
  // =====================================================================

  Future<bool> addShipping({
    required String stockItemId,
    required DateTime shippingDate,
    required double quantity,
    String? destination,
    String? staff,
    String? note,
  }) async {
    final item = _stockBox.get(stockItemId);
    if (item == null) return false;

    if (quantity > item.currentStock) {
      return false;
    }

    final record = ShippingRecord(
      id: _uuid.v4(),
      stockItemId: stockItemId,
      category: item.category,
      spec: item.spec,
      unit: item.unit,
      shippingDate: shippingDate,
      quantity: quantity,
      destination: destination,
      staff: staff,
      note: note,
      location: item.location,
    );

    await _shippingBox.put(record.id, record);
    _recalculateStock(stockItemId);
    notifyListeners();
    return true;
  }

  // =====================================================================
  // 履歴削除
  // =====================================================================

  Future<void> deleteDelivery(String recordId) async {
    final record = _deliveryBox.get(recordId);
    if (record == null) return;
    // 該当の在庫項目を category+spec+location で探して再計算
    final affected = _stockBox.values.firstWhere(
      (i) =>
          i.category == record.category &&
          i.spec == record.spec &&
          i.location == record.location,
      orElse: () => _stockBox.values.first,
    );
    await _deliveryBox.delete(recordId);
    _recalculateStock(affected.id);
    notifyListeners();
  }

  Future<void> deleteShipping(String recordId) async {
    final record = _shippingBox.get(recordId);
    if (record == null) return;
    final affected = _stockBox.values.firstWhere(
      (i) =>
          i.category == record.category &&
          i.spec == record.spec &&
          i.location == record.location,
      orElse: () => _stockBox.values.first,
    );
    await _shippingBox.delete(recordId);
    _recalculateStock(affected.id);
    notifyListeners();
  }

  // =====================================================================
  // 備考更新
  // =====================================================================

  Future<void> updateNote(String stockItemId, String? note) async {
    final item = _stockBox.get(stockItemId);
    if (item == null) return;
    item.note = note;
    await item.save();
    notifyListeners();
  }

  // =====================================================================
  // ゲッター・フィルター
  // =====================================================================

  StockItem? getStockItem(String id) => _stockBox.get(id);

  /// 指定カテゴリ・規格・場所の在庫項目を取得
  StockItem? findStockItem({
    required String category,
    required String spec,
    required String location,
  }) {
    for (final i in _stockBox.values) {
      if (i.category == category && i.spec == spec && i.location == location) {
        return i;
      }
    }
    return null;
  }

  /// 定義順に並んだカテゴリ一覧（重複なし）
  List<String> get categories {
    final seen = <String>{};
    final result = <String>[];
    for (final m in _itemOrder) {
      final cat = m['category']!;
      if (seen.add(cat)) result.add(cat);
    }
    return result;
  }

  /// 指定カテゴリの規格を定義順で返す
  List<String> getSpecsForCategory(String category) {
    return _itemOrder
        .where((m) => m['category'] == category)
        .map((m) => m['spec']!)
        .toList();
  }

  /// 「カテゴリ＋規格」単位のユニークな品目ペアリスト（定義順）
  List<Map<String, String>> get itemPairs =>
      List.unmodifiable(_itemOrder.map((m) => Map<String, String>.from(m)));

  /// 指定場所の在庫項目のみを返す（定義順ソート済み）
  List<StockItem> getStockItemsByLocation(String location) {
    return stockItems.where((i) => i.location == location).toList();
  }

  /// 在庫一覧の「品目別 × 場所別」サマリー
  /// 各品目（category+spec）に対し、本社・第二・合計を返す
  List<StockSummary> get stockSummaries {
    final list = <StockSummary>[];
    for (final pair in _itemOrder) {
      final cat = pair['category']!;
      final spec = pair['spec']!;
      final honsha = findStockItem(
          category: cat, spec: spec, location: locationHonsha);
      final daini = findStockItem(
          category: cat, spec: spec, location: locationDaini);
      // unit は本社→第二の順で取得（どちらも同じ）
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
    var items = stockItems;
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
    var records = deliveryRecords;
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
      records = records.where((r) => !r.deliveryDate.isBefore(fromDate)).toList();
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
    var records = shippingRecords;
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
      records = records.where((r) => !r.shippingDate.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final end = toDate.add(const Duration(days: 1));
      records = records.where((r) => r.shippingDate.isBefore(end)).toList();
    }
    return records;
  }

  List<StockItem> get lowStockItems =>
      stockItems.where((i) => i.currentStock <= i.lowStockThreshold).toList();
}

/// 在庫一覧サマリー: 品目（category+spec）ごとに、本社/第二/合計を保持
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
