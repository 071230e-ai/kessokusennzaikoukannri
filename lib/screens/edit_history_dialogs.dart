// 履歴編集用ダイアログ
//
// `showEditDeliveryDialog` / `showEditShippingDialog` を公開する。
// それぞれ既存の DeliveryRecord / ShippingRecord を受け取り、ダイアログ内で
// 編集 → 確認 → StockProvider.updateDelivery / updateShipping を呼び出す。
//
// スマホでも使いやすいよう、全幅のフォームを縦に並べた構成にしている。
import 'package:flutter/material.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../providers/stock_provider.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

// =====================================================================
// 納入履歴 編集ダイアログ
// =====================================================================

Future<void> showEditDeliveryDialog(
  BuildContext context,
  DeliveryRecord record,
  StockProvider provider,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditDeliveryDialog(record: record, provider: provider),
  );
}

class _EditDeliveryDialog extends StatefulWidget {
  final DeliveryRecord record;
  final StockProvider provider;
  const _EditDeliveryDialog({required this.record, required this.provider});

  @override
  State<_EditDeliveryDialog> createState() => _EditDeliveryDialogState();
}

class _EditDeliveryDialogState extends State<_EditDeliveryDialog> {
  late DateTime _date;
  late String _location;
  late String _category;
  late String _spec;
  late TextEditingController _qtyCtrl;
  late TextEditingController _supplierCtrl;
  late TextEditingController _staffCtrl;
  late TextEditingController _noteCtrl;
  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _date = r.deliveryDate;
    _location = r.location;
    _category = r.category;
    _spec = r.spec;
    _qtyCtrl = TextEditingController(text: _formatQty(r.quantity));
    _supplierCtrl = TextEditingController(text: r.supplier ?? '');
    _staffCtrl = TextEditingController(text: r.staff ?? '');
    _noteCtrl = TextEditingController(text: r.note ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _supplierCtrl.dispose();
    _staffCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  /// 現在の品目・規格から単位を取得（フォールバックは元レコードの単位）
  String get _currentUnit {
    final item = widget.provider
        .findStockItem(category: _category, spec: _spec, location: _location);
    return item?.unit ?? widget.record.unit;
  }

  Future<void> _onSave() async {
    setState(() => _errorMsg = null);

    // 入力チェック
    final qtyText = _qtyCtrl.text.trim();
    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      setState(() => _errorMsg = '数量は0より大きい数値を入力してください');
      return;
    }

    // 場所・品目から StockItem を解決
    final item = widget.provider.findStockItem(
        category: _category, spec: _spec, location: _location);
    if (item == null) {
      setState(() => _errorMsg = '指定された保管場所・品目の組み合わせが存在しません');
      return;
    }

    // 確認ダイアログ
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('修正内容の確認'),
        content: const Text('この内容で履歴を修正しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx2, true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('修正する'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await widget.provider.updateDelivery(
        recordId: widget.record.id,
        stockItemId: item.id,
        deliveryDate: _date,
        quantity: qty,
        supplier: _supplierCtrl.text.trim().isEmpty
            ? null
            : _supplierCtrl.text.trim(),
        staff: _staffCtrl.text.trim().isEmpty ? null : _staffCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('修正しました'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = '保存に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final categories = provider.categories;
    final specs = provider.getSpecsForCategory(_category);
    // 規格が現在のカテゴリに存在しない場合は先頭にフォールバック
    if (!specs.contains(_spec) && specs.isNotEmpty) {
      _spec = specs.first;
    }

    return AlertDialog(
      title: const Text('納入履歴の編集'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('日付'),
              _datePickerField(_date, (d) => setState(() => _date = d)),
              const SizedBox(height: 12),
              _label('保管場所'),
              _locationToggle(_location, (v) => setState(() => _location = v)),
              const SizedBox(height: 12),
              _label('品目'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _category = v;
                    final newSpecs = provider.getSpecsForCategory(v);
                    if (!newSpecs.contains(_spec)) {
                      _spec = newSpecs.isNotEmpty ? newSpecs.first : '-';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _label('規格長さ'),
              DropdownButtonFormField<String>(
                initialValue: specs.contains(_spec) ? _spec : null,
                isExpanded: true,
                items: specs
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _spec = v);
                },
              ),
              const SizedBox(height: 12),
              _label('数量 ($_currentUnit)'),
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: _currentUnit,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              _label('仕入先'),
              TextField(
                controller: _supplierCtrl,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 12),
              _label('担当者'),
              TextField(
                controller: _staffCtrl,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 12),
              _label('備考'),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(isDense: true),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(_errorMsg!,
                    style: const TextStyle(
                        color: AppTheme.warningRed, fontSize: 13)),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _onSave,
          style: ElevatedButton.styleFrom(minimumSize: const Size(96, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

// =====================================================================
// 出荷・使用履歴 編集ダイアログ
// =====================================================================

Future<void> showEditShippingDialog(
  BuildContext context,
  ShippingRecord record,
  StockProvider provider,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditShippingDialog(record: record, provider: provider),
  );
}

class _EditShippingDialog extends StatefulWidget {
  final ShippingRecord record;
  final StockProvider provider;
  const _EditShippingDialog({required this.record, required this.provider});

  @override
  State<_EditShippingDialog> createState() => _EditShippingDialogState();
}

class _EditShippingDialogState extends State<_EditShippingDialog> {
  late DateTime _date;
  late String _location;
  late String _category;
  late String _spec;
  late TextEditingController _qtyCtrl;
  late TextEditingController _destinationCtrl;
  late TextEditingController _staffCtrl;
  late TextEditingController _noteCtrl;
  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _date = r.shippingDate;
    _location = r.location;
    _category = r.category;
    _spec = r.spec;
    _qtyCtrl = TextEditingController(text: _formatQty(r.quantity));
    _destinationCtrl = TextEditingController(text: r.destination ?? '');
    _staffCtrl = TextEditingController(text: r.staff ?? '');
    _noteCtrl = TextEditingController(text: r.note ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _destinationCtrl.dispose();
    _staffCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  String get _currentUnit {
    final item = widget.provider
        .findStockItem(category: _category, spec: _spec, location: _location);
    return item?.unit ?? widget.record.unit;
  }

  /// 編集時の使用可能在庫を計算する：
  ///   - 同じ品目・同じ場所への修正 → current_stock + 元の出荷数量
  ///   - 別の品目または別の場所への変更 → 移動先の current_stock のみ
  double _calcAvailableQty() {
    final item = widget.provider
        .findStockItem(category: _category, spec: _spec, location: _location);
    if (item == null) return 0;
    final r = widget.record;
    final isSameDestination =
        item.itemId == r.itemId && item.locationId == r.locationId;
    return item.currentStock + (isSameDestination ? r.quantity : 0);
  }

  Future<void> _onSave() async {
    setState(() => _errorMsg = null);

    final qtyText = _qtyCtrl.text.trim();
    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      setState(() => _errorMsg = '数量は0より大きい数値を入力してください');
      return;
    }

    final item = widget.provider.findStockItem(
        category: _category, spec: _spec, location: _location);
    if (item == null) {
      setState(() => _errorMsg = '指定された保管場所・品目の組み合わせが存在しません');
      return;
    }

    // クライアント側でも在庫チェック（最終的にはサーバ側の 409 が真）
    final available = _calcAvailableQty();
    if (qty > available) {
      setState(() => _errorMsg =
          '使用可能在庫を超えています（使用可能: ${_formatQty(available)} ${item.unit}）');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('修正内容の確認'),
        content: const Text('この内容で履歴を修正しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx2, true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('修正する'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final success = await widget.provider.updateShipping(
        recordId: widget.record.id,
        stockItemId: item.id,
        shippingDate: _date,
        quantity: qty,
        destination: _destinationCtrl.text.trim().isEmpty
            ? null
            : _destinationCtrl.text.trim(),
        staff: _staffCtrl.text.trim().isEmpty ? null : _staffCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      if (!success) {
        // サーバ側で 409 → 最新在庫を再計算してメッセージを表示
        final newAvail = _calcAvailableQty();
        setState(() {
          _saving = false;
          _errorMsg =
              '在庫不足のため保存できませんでした（使用可能: ${_formatQty(newAvail)} ${item.unit}）';
        });
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('修正しました'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = '保存に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final categories = provider.categories;
    final specs = provider.getSpecsForCategory(_category);
    if (!specs.contains(_spec) && specs.isNotEmpty) {
      _spec = specs.first;
    }
    final available = _calcAvailableQty();

    return AlertDialog(
      title: const Text('出荷・使用履歴の編集'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('日付'),
              _datePickerField(_date, (d) => setState(() => _date = d)),
              const SizedBox(height: 12),
              _label('保管場所'),
              _locationToggle(_location, (v) => setState(() => _location = v)),
              const SizedBox(height: 12),
              _label('品目'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _category = v;
                    final newSpecs = provider.getSpecsForCategory(v);
                    if (!newSpecs.contains(_spec)) {
                      _spec = newSpecs.isNotEmpty ? newSpecs.first : '-';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _label('規格長さ'),
              DropdownButtonFormField<String>(
                initialValue: specs.contains(_spec) ? _spec : null,
                isExpanded: true,
                items: specs
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _spec = v);
                },
              ),
              const SizedBox(height: 12),
              _label('数量 ($_currentUnit)'),
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: _currentUnit,
                  isDense: true,
                  helperText:
                      '使用可能: ${_formatQty(available)} $_currentUnit',
                ),
              ),
              const SizedBox(height: 12),
              _label('出荷先または使用先'),
              TextField(
                controller: _destinationCtrl,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 12),
              _label('担当者'),
              TextField(
                controller: _staffCtrl,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 12),
              _label('備考'),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(isDense: true),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(_errorMsg!,
                    style: const TextStyle(
                        color: AppTheme.warningRed, fontSize: 13)),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _onSave,
          style: ElevatedButton.styleFrom(minimumSize: const Size(96, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

// =====================================================================
// 共通 UI ヘルパー
// =====================================================================

Widget _label(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 2),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary)),
  );
}

Widget _datePickerField(DateTime date, void Function(DateTime) onChanged) {
  return Builder(builder: (context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Text(DateFormatter.format(date),
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  });
}

Widget _locationToggle(String location, void Function(String) onChanged) {
  return Row(
    children: StockProvider.locations.map((loc) {
      final selected = loc == location;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(loc),
          child: Container(
            margin: EdgeInsets.only(
                right: loc == StockProvider.locations.first ? 6 : 0,
                left: loc == StockProvider.locations.last ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppTheme.backgroundGreen : Colors.white,
              border: Border.all(
                color:
                    selected ? AppTheme.primaryGreen : AppTheme.borderColor,
                width: selected ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                loc,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}
