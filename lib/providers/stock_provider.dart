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
    {'category': '18番結束線', 'spec': '550mm'},
    {'category': '18番結束線', 'spec': '700mm'},
    {'category': 'タイワイヤ', 'spec': '-'},
  ];

  /// 品目の定義順インデックスを返す（並び替えに使用）
  int _itemSortIndex(StockItem item) {
    for (int i = 0; i < _itemOrder.length; i++) {
      if (_itemOrder[i]['category'] == item.category &&
          _itemOrder[i]['spec'] == item.spec) {
        return i;
      }
    }
    return _itemOrder.length; // 未定義品目は末尾
  }

  /// 定義順にソートされた全在庫リスト
  List<StockItem> get stockItems {
    final list = _stockBox.values.toList();
    list.sort((a, b) => _itemSortIndex(a).compareTo(_itemSortIndex(b)));
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
    }
  }

  Future<void> _initializeDefaultItems() async {
    final defaultItems = [
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '350mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '400mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '450mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '500mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '550mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '600mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '650mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '結束線',    spec: '700mm', unit: 'kg',  lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '18番結束線', spec: '550mm', unit: 'kg', lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: '18番結束線', spec: '700mm', unit: 'kg', lowStockThreshold: 20),
      StockItem(id: _uuid.v4(), category: 'タイワイヤ',  spec: '-',    unit: '箱', lowStockThreshold: 5),
    ];
    for (final item in defaultItems) {
      await _stockBox.put(item.id, item);
    }
  }

  // =====================================================================
  // 初期在庫の更新
  // =====================================================================

  /// 1件の初期在庫を更新し現在庫を再計算する
  Future<void> updateInitialStock(String stockItemId, double newInitialStock) async {
    final item = _stockBox.get(stockItemId);
    if (item == null) return;
    item.initialStock = newInitialStock;
    await item.save();
    _recalculateStock(stockItemId);
    notifyListeners();
  }

  /// 全品目の初期在庫を一括更新する
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
  // 在庫再計算
  // =====================================================================

  void _recalculateStock(String stockItemId) {
    final item = _stockBox.get(stockItemId);
    if (item == null) return;

    final totalDelivery = _deliveryBox.values
        .where((r) => r.stockItemId == stockItemId)
        .fold<double>(0, (sum, r) => sum + r.quantity);

    final totalShipping = _shippingBox.values
        .where((r) => r.stockItemId == stockItemId)
        .fold<double>(0, (sum, r) => sum + r.quantity);

    // 現在庫 = 初期在庫 + 納入合計 - 出荷・使用合計
    item.currentStock = item.initialStock + totalDelivery - totalShipping;

    // 最終納入日
    final deliveryList = _deliveryBox.values
        .where((r) => r.stockItemId == stockItemId)
        .toList();
    if (deliveryList.isNotEmpty) {
      deliveryList.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
      item.lastDeliveryDate = deliveryList.first.deliveryDate;
    } else {
      item.lastDeliveryDate = null;
    }

    // 最終出荷日
    final shippingList = _shippingBox.values
        .where((r) => r.stockItemId == stockItemId)
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
      return false; // 在庫不足
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
    final stockItemId = record.stockItemId;
    await _deliveryBox.delete(recordId);
    _recalculateStock(stockItemId);
    notifyListeners();
  }

  Future<void> deleteShipping(String recordId) async {
    final record = _shippingBox.get(recordId);
    if (record == null) return;
    final stockItemId = record.stockItemId;
    await _shippingBox.delete(recordId);
    _recalculateStock(stockItemId);
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

  List<StockItem> getFilteredStockItems({
    String? category,
    String? spec,
    String? sortBy, // 'stock_asc', 'stock_desc'
  }) {
    var items = stockItems; // すでに定義順でソート済み
    if (category != null && category.isNotEmpty) {
      items = items.where((i) => i.category == category).toList();
    }
    if (spec != null && spec.isNotEmpty) {
      items = items.where((i) => i.spec == spec).toList();
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
