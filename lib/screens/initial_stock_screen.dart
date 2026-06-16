import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

class InitialStockScreen extends StatefulWidget {
  const InitialStockScreen({super.key});

  @override
  State<InitialStockScreen> createState() => _InitialStockScreenState();
}

class _InitialStockScreenState extends State<InitialStockScreen> {
  // 各品目IDに対応するTextEditingController
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  // ignore: unused_field
  bool _hasChanges = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// コントローラを初期化（品目リスト確定後に呼ぶ）
  void _initControllers(List<StockItem> items) {
    for (final item in items) {
      if (!_controllers.containsKey(item.id)) {
        final ctrl = TextEditingController(
          text: item.initialStock == 0
              ? ''
              : DateFormatter.quantityStr(item.initialStock),
        );
        ctrl.addListener(() => setState(() => _hasChanges = true));
        _controllers[item.id] = ctrl;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final items = provider.stockItems;
        _initControllers(items);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              // 説明バナー
              _buildInfoBanner(),

              // テーブルヘッダー
              _buildTableHeader(),

              // 品目リスト
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemBuilder: (context, index) {
                    return _buildItemRow(context, items[index]);
                  },
                ),
              ),

              // 保存ボタンエリア
              _buildSaveArea(provider, items),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_outlined, color: AppTheme.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '初期在庫設定',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '現在の実際の在庫数を入力してください。\n'
              '現在庫 ＝ 初期在庫 ＋ 納入合計 − 出荷・使用合計\n'
              '空欄は 0 として扱われます。',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text('品目', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          ),
          Expanded(
            flex: 2,
            child: Text('規格', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          ),
          SizedBox(
            width: 40,
            child: Text('単位', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          ),
          Expanded(
            flex: 3,
            child: Text('初期在庫', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, StockItem item) {
    final ctrl = _controllers[item.id];
    if (ctrl == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // 品目名
            Expanded(
              flex: 3,
              child: Text(
                item.category,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // 規格
            Expanded(
              flex: 2,
              child: Text(
                item.spec,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            // 単位
            SizedBox(
              width: 40,
              child: Text(
                item.unit,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            // 初期在庫入力欄
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.borderColor),
                  suffixText: item.unit,
                  suffixStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveArea(StockProvider provider, List<StockItem> items) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 保存ボタン
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _saveAll(context, provider, items),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('初期在庫を保存する', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          // 全クリアボタン
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _showClearConfirm(context, items),
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('全項目をクリア', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll(
    BuildContext context,
    StockProvider provider,
    List<StockItem> items,
  ) async {
    setState(() => _isSaving = true);

    // バリデーション
    final Map<String, double> updates = {};
    for (final item in items) {
      final ctrl = _controllers[item.id];
      if (ctrl == null) continue;
      final text = ctrl.text.trim();
      if (text.isEmpty) {
        updates[item.id] = 0;
      } else {
        final val = double.tryParse(text);
        if (val == null || val < 0) {
          setState(() => _isSaving = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.displayName} の入力値が不正です（0以上の数値を入力してください）'),
                backgroundColor: AppTheme.warningRed,
              ),
            );
          }
          return;
        }
        updates[item.id] = val;
      }
    }

    await provider.updateAllInitialStocks(updates);

    setState(() {
      _isSaving = false;
      _hasChanges = false;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('初期在庫を保存しました。在庫数に反映されました。'),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showClearConfirm(BuildContext context, List<StockItem> items) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全項目をクリア'),
        content: const Text('全品目の初期在庫入力欄を 0 にリセットします。\nよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final ctrl in _controllers.values) {
                ctrl.text = '';
              }
              setState(() => _hasChanges = true);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
  }
}
