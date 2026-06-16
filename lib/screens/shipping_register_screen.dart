import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

/// 出荷・使用登録画面（複数明細対応）
///
/// 共通項目:
///   - 日付
///   - 保管場所（出荷元）
///   - 出荷先・使用場所
///   - 担当者
///   - 備考
///
/// 明細リスト (1行ごと):
///   - 品目 / 規格・長さ / 数量 / 単位表示
///   - 「+ 行を追加」ボタンで追加可能
///   - 各行に削除ボタン
///
/// 在庫検証:
///   - 同一品目を複数行で出した場合の合計数量が現在庫を超えないかをチェック
class ShippingRegisterScreen extends StatefulWidget {
  const ShippingRegisterScreen({super.key});

  @override
  State<ShippingRegisterScreen> createState() => _ShippingRegisterScreenState();
}

class _ShippingRegisterScreenState extends State<ShippingRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---- 共通項目 ----
  DateTime _selectedDate = DateTime.now();
  String? _selectedLocation;
  final _destinationCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // ---- 明細リスト ----
  final List<_ShippingLine> _lines = [_ShippingLine()];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _staffCtrl.dispose();
    _noteCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // =====================================================================
  // build
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),

                      // ===== 共通項目カード =====
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('出荷・使用日 *'),
                              _buildDatePicker(),
                              const SizedBox(height: 16),

                              _buildLabel('保管場所（出荷元）*'),
                              _buildLocationSelector(provider),
                              const SizedBox(height: 16),

                              _buildLabel('出荷先・使用場所'),
                              TextFormField(
                                controller: _destinationCtrl,
                                decoration: const InputDecoration(
                                    hintText: '出荷先や使用場所を入力'),
                              ),
                              const SizedBox(height: 16),

                              _buildLabel('担当者'),
                              TextFormField(
                                controller: _staffCtrl,
                                decoration: const InputDecoration(
                                    hintText: '担当者名を入力'),
                              ),
                              const SizedBox(height: 16),

                              _buildLabel('備考'),
                              TextFormField(
                                controller: _noteCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: '備考を入力',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== 明細セクション ヘッダー =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '出荷・使用明細',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_lines.length} 明細',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ===== 明細リスト =====
                      ...List.generate(_lines.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildLineCard(provider, index),
                        );
                      }),

                      // ===== 行追加ボタン =====
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _addLine,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('行を追加'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: Colors.orange.shade700,
                          side: BorderSide(
                              color: Colors.orange.shade700, width: 1.5),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ===== 登録ボタン =====
                      ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(provider),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.output_rounded),
                        label: Text(
                            '出荷・使用を登録する (${_lines.length} 明細)'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _resetForm,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('フォームをリセット'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 明細カード
  // =====================================================================

  Widget _buildLineCard(StockProvider provider, int index) {
    final line = _lines[index];
    final categories = provider.categories;
    final specs = line.category != null
        ? provider.getSpecsForCategory(line.category!)
        : <String>[];

    StockItem? resolved;
    if (_selectedLocation != null &&
        line.category != null &&
        line.spec != null) {
      resolved = provider.findStockItem(
        category: line.category!,
        spec: line.spec!,
        location: _selectedLocation!,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '明細 ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _removeLine(index),
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.warningRed),
                    tooltip: 'この明細を削除',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            _buildLabel('品目 *'),
            DropdownButtonFormField<String>(
              initialValue: line.category,
              decoration: const InputDecoration(hintText: '品目を選択'),
              items: categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() {
                line.category = v;
                line.spec = null;
              }),
              validator: (v) => v == null ? '品目を選択してください' : null,
            ),
            const SizedBox(height: 12),

            _buildLabel('規格・長さ *'),
            DropdownButtonFormField<String>(
              initialValue: line.spec,
              decoration: const InputDecoration(
                hintText: '品目を先に選択してください',
              ),
              items: specs
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: line.category == null
                  ? null
                  : (v) => setState(() {
                        line.spec = v;
                      }),
              validator: (v) =>
                  v == null ? '規格・長さを選択してください' : null,
            ),

            if (resolved != null) ...[
              const SizedBox(height: 8),
              _buildCurrentStockBadge(resolved),
            ],

            const SizedBox(height: 12),

            _buildLabel('数量 *'),
            TextFormField(
              controller: line.quantityCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: resolved?.unit ?? '',
              ),
              // 行単体での簡易チェック（在庫超過は _submit で集約チェック）
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return '数量を入力してください';
                }
                final n = double.tryParse(v);
                if (n == null) return '数値を入力してください';
                if (n <= 0) return '0より大きい値を入力してください';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // 共通ウィジェット
  // =====================================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: const Row(
        children: [
          Icon(Icons.output_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '日付・保管場所・出荷先は全明細で共通です。複数の品目をまとめて登録できます。',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildLocationSelector(StockProvider provider) {
    return FormField<String>(
      initialValue: _selectedLocation,
      validator: (v) => (v == null || v.isEmpty) ? '保管場所を選択してください' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: StockProvider.locations.map((loc) {
              final selected = _selectedLocation == loc;
              final iconData = loc == StockProvider.locationHonsha
                  ? Icons.factory_outlined
                  : Icons.warehouse_outlined;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLocation = loc;
                      });
                      field.didChange(loc);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.orange.shade700
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? Colors.orange.shade700
                              : AppTheme.borderColor,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            loc,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(field.errorText!,
                  style: const TextStyle(
                      color: AppTheme.warningRed, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              DateFormatter.format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStockBadge(StockItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGreen,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${item.location} の現在庫: ${DateFormatter.formatQuantity(item.currentStock, item.unit)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // 明細操作
  // =====================================================================

  void _addLine() {
    setState(() {
      _lines.add(_ShippingLine());
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  // =====================================================================
  // 登録処理
  // =====================================================================

  Future<void> _submit(StockProvider provider) async {
    if (_lines.isEmpty) {
      _showError('明細を1行以上追加してください');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // 各明細から StockItem を解決
    final resolvedLines = <_ResolvedLine>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final qty = double.tryParse(line.quantityCtrl.text);
      if (qty == null || qty <= 0) {
        _showError('明細${i + 1}: 数量が正しくありません');
        return;
      }
      final item = provider.findStockItem(
        category: line.category!,
        spec: line.spec!,
        location: _selectedLocation!,
      );
      if (item == null) {
        _showError('明細${i + 1}: 該当する在庫品目が見つかりません');
        return;
      }
      resolvedLines.add(_ResolvedLine(item: item, quantity: qty));
    }

    // 同一品目の合計数量が現在庫を超えないかチェック
    final Map<String, double> totalByItemId = {};
    final Map<String, StockItem> itemById = {};
    for (final r in resolvedLines) {
      totalByItemId.update(r.item.id, (v) => v + r.quantity,
          ifAbsent: () => r.quantity);
      itemById[r.item.id] = r.item;
    }
    final insufficient = <String>[];
    totalByItemId.forEach((id, total) {
      final it = itemById[id]!;
      if (total > it.currentStock) {
        insufficient.add(
            '${it.displayName}: 必要 ${DateFormatter.formatQuantity(total, it.unit)} / 現在庫 ${DateFormatter.formatQuantity(it.currentStock, it.unit)}');
      }
    });
    if (insufficient.isNotEmpty) {
      await _showInsufficientDialog(insufficient);
      return;
    }

    // 確認ダイアログ
    final ok = await _showConfirmDialog(resolvedLines);
    if (ok != true) return;

    // 順次登録
    setState(() => _isSubmitting = true);
    int successCount = 0;
    final failedLines = <String>[];
    for (var i = 0; i < resolvedLines.length; i++) {
      final r = resolvedLines[i];
      try {
        final success = await provider.addShipping(
          stockItemId: r.item.id,
          shippingDate: _selectedDate,
          quantity: r.quantity,
          destination: _destinationCtrl.text.isEmpty
              ? null
              : _destinationCtrl.text,
          staff: _staffCtrl.text.isEmpty ? null : _staffCtrl.text,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        );
        if (success) {
          successCount++;
        } else {
          failedLines
              .add('明細${i + 1} (${r.item.displayName}) - 在庫不足');
        }
      } catch (e) {
        failedLines.add('明細${i + 1} (${r.item.displayName})');
      }
    }
    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (failedLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登録しました（$successCount 明細）'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      _resetForm();
    } else {
      _showError(
          '一部の登録に失敗しました\n成功: $successCount 件\n失敗: ${failedLines.join("、")}');
    }
  }

  Future<bool?> _showConfirmDialog(List<_ResolvedLine> lines) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.output_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('出荷・使用登録の確認'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('日付: ${DateFormatter.format(_selectedDate)}'),
                Text('保管場所: $_selectedLocation'),
                if (_destinationCtrl.text.isNotEmpty)
                  Text('出荷先・使用場所: ${_destinationCtrl.text}'),
                if (_staffCtrl.text.isNotEmpty)
                  Text('担当者: ${_staffCtrl.text}'),
                if (_noteCtrl.text.isNotEmpty)
                  Text('備考: ${_noteCtrl.text}'),
                const Divider(height: 20),
                const Text('明細:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...lines.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${i + 1}. ${r.item.displayName}  ${DateFormatter.formatQuantity(r.quantity, r.item.unit)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  '合計 ${lines.length} 明細を登録します。よろしいですか？',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700),
            child: const Text('登録する'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInsufficientDialog(List<String> insufficient) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningRed),
            SizedBox(width: 8),
            Text('在庫不足',
                style: TextStyle(color: AppTheme.warningRed)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('以下の品目で在庫が不足しています:'),
            const SizedBox(height: 8),
            ...insufficient.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $s',
                      style: const TextStyle(fontSize: 13)),
                )),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.warningRed,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _resetForm() {
    for (final l in _lines) {
      l.dispose();
    }
    setState(() {
      _selectedDate = DateTime.now();
      _selectedLocation = null;
      _lines
        ..clear()
        ..add(_ShippingLine());
    });
    _destinationCtrl.clear();
    _staffCtrl.clear();
    _noteCtrl.clear();
    _formKey.currentState?.reset();
  }
}

/// 1明細分のローカル状態
class _ShippingLine {
  String? category;
  String? spec;
  final TextEditingController quantityCtrl = TextEditingController();

  void dispose() {
    quantityCtrl.dispose();
  }
}

/// バリデーション通過後の確定明細
class _ResolvedLine {
  final StockItem item;
  final double quantity;
  const _ResolvedLine({required this.item, required this.quantity});
}
