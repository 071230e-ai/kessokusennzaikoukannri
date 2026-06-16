import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import '../utils/csv_export.dart';
import 'initial_stock_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  String? _selectedCategory;
  String? _selectedSpec;
  String _sortBy = '';
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final items = provider.getFilteredStockItems(
          category: _selectedCategory,
          spec: _selectedSpec,
          sortBy: _sortBy.isEmpty ? null : _sortBy,
        );
        final categories = provider.categories;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              // フィルターエリア
              _buildFilterArea(context, provider, categories),

              // テーブルヘッダー（スクロール可能なヘッダー付きリスト）
              Expanded(
                child: Column(
                  children: [
                    _buildTableHeader(),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text('該当する品目がありません',
                                  style: TextStyle(color: AppTheme.textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) =>
                                  _buildStockRow(context, items[index], provider),
                            ),
                    ),
                  ],
                ),
              ),

              // 下部ボタンエリア
              _buildBottomButtons(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterArea(
      BuildContext context, StockProvider provider, List<String> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '品目',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('すべて')),
                    ...categories.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedCategory = v;
                    _selectedSpec = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSpec,
                  decoration: const InputDecoration(
                    labelText: '規格',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('すべて')),
                    ...(_selectedCategory != null
                        ? provider
                            .getSpecsForCategory(_selectedCategory!)
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13))))
                        : []),
                  ],
                  onChanged: (v) => setState(() => _selectedSpec = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('並び替え：',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              _sortChip('多い順', 'stock_desc'),
              const SizedBox(width: 6),
              _sortChip('少ない順', 'stock_asc'),
              const SizedBox(width: 6),
              if (_sortBy.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _sortBy = ''),
                  child: const Text('リセット',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryGreen,
                          decoration: TextDecoration.underline)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = selected ? '' : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primaryGreen : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: const [
          Expanded(
              flex: 3,
              child: Text('品目',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 2,
              child: Text('規格',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 2,
              child: Text('初期在庫',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 2,
              child: Text('現在庫',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _buildStockRow(
      BuildContext context, StockItem item, StockProvider provider) {
    final isLow = item.currentStock <= item.lowStockThreshold;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: () => _showDetailDialog(context, item, provider),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isLow
                ? Border.all(color: AppTheme.warningRed, width: 1.5)
                : null,
            color: isLow ? AppTheme.warningRedLight : Colors.white,
          ),
          child: Row(
            children: [
              // 品目
              Expanded(
                flex: 3,
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLow ? AppTheme.warningRed : AppTheme.textPrimary,
                  ),
                ),
              ),
              // 規格
              Expanded(
                flex: 2,
                child: Text(
                  item.spec,
                  style: TextStyle(
                      fontSize: 12,
                      color: isLow
                          ? AppTheme.warningRed
                          : AppTheme.textSecondary),
                ),
              ),
              // 初期在庫
              Expanded(
                flex: 2,
                child: Text(
                  DateFormatter.formatQuantity(item.initialStock, item.unit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              // 現在庫
              Expanded(
                flex: 2,
                child: Text(
                  DateFormatter.formatQuantity(item.currentStock, item.unit),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isLow
                        ? AppTheme.warningRed
                        : AppTheme.primaryGreen,
                  ),
                ),
              ),
              // 詳細ボタン
              IconButton(
                icon: const Icon(Icons.edit_note,
                    size: 20, color: AppTheme.textSecondary),
                onPressed: () => _showDetailDialog(context, item, provider),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(
      BuildContext context, StockItem item, StockProvider provider) {
    _noteController.text = item.note ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.displayName,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('品目', item.category),
              _detailRow('規格', item.spec),
              _detailRow('単位', item.unit),
              const Divider(height: 16),
              _detailRow(
                  '初期在庫',
                  DateFormatter.formatQuantity(
                      item.initialStock, item.unit)),
              _detailRow(
                  '現在庫',
                  DateFormatter.formatQuantity(
                      item.currentStock, item.unit)),
              const Divider(height: 16),
              _detailRow(
                  '最終納入日', DateFormatter.format(item.lastDeliveryDate)),
              _detailRow(
                  '最終出荷日', DateFormatter.format(item.lastShippingDate)),
              const SizedBox(height: 12),
              const Text('備考',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '備考を入力...',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateNote(
                  item.id,
                  _noteController.text.isEmpty
                      ? null
                      : _noteController.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('備考を保存しました'),
                    duration: Duration(seconds: 1)),
              );
            },
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, StockProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // 初期在庫設定ボタン（追加）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('初期在庫を設定する', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('村田鉄筋㈱ 在庫管理',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('初期在庫設定',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                        backgroundColor: AppTheme.headerBg,
                      ),
                      body: const InitialStockScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('CSV出力', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: () => _showCsvDownloadDialog(context, provider),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('印刷', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: () => _showPrintDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCsvDownloadDialog(
      BuildContext context, StockProvider provider) {
    final csv = CsvExport.generateStockCsv(provider.stockItems);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('在庫一覧 CSV'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style:
                  const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる')),
        ],
      ),
    );
  }

  void _showPrintDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('印刷プレビュー'),
        content: const Text(
            'ブラウザの印刷機能をご利用ください。\nCtrl+P（Windows）/ ⌘+P（Mac）'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
