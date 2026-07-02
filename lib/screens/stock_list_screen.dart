import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
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
  String _sortBy = ''; // 'total_asc', 'total_desc'
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
        var summaries = provider.stockSummaries;
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          summaries =
              summaries.where((s) => s.category == _selectedCategory).toList();
        }
        if (_selectedSpec != null && _selectedSpec!.isNotEmpty) {
          summaries =
              summaries.where((s) => s.spec == _selectedSpec).toList();
        }
        if (_sortBy == 'total_asc') {
          summaries.sort((a, b) => a.totalStock.compareTo(b.totalStock));
        } else if (_sortBy == 'total_desc') {
          summaries.sort((a, b) => b.totalStock.compareTo(a.totalStock));
        }
        final categories = provider.categories;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              _buildFilterArea(context, provider, categories),
              Expanded(
                child: Column(
                  children: [
                    _buildTableHeader(),
                    Expanded(
                      child: summaries.isEmpty
                          ? const Center(
                              child: Text('該当する品目がありません',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: summaries.length,
                              itemBuilder: (context, index) =>
                                  _buildSummaryRow(
                                      context, summaries[index], provider),
                            ),
                    ),
                  ],
                ),
              ),
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
              const Text('合計で並び替え：',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              _sortChip('多い順', 'total_desc'),
              const SizedBox(width: 6),
              _sortChip('少ない順', 'total_asc'),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: const [
          Expanded(
              flex: 4,
              child: Text('品目',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 3,
              child: Text('本社工場',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 3,
              child: Text('第二工場',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          Expanded(
              flex: 3,
              child: Text('合計',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen))),
          SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, StockSummary s, StockProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: () => _showDetailDialog(context, s, provider),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // 品目（カテゴリ + 規格を2行表示）
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (s.spec != '-')
                      Text(
                        s.spec,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              // 本社工場
              Expanded(
                flex: 3,
                child: Text(
                  DateFormatter.formatQuantity(s.honshaStock, s.unit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // 第二工場
              Expanded(
                flex: 3,
                child: Text(
                  DateFormatter.formatQuantity(s.dainiStock, s.unit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // 合計
              Expanded(
                flex: 3,
                child: Text(
                  DateFormatter.formatQuantity(s.totalStock, s.unit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              // 詳細ボタン
              IconButton(
                icon: const Icon(Icons.edit_note,
                    size: 18, color: AppTheme.textSecondary),
                onPressed: () => _showDetailDialog(context, s, provider),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(
      BuildContext context, StockSummary s, StockProvider provider) {
    // 備考は両工場の在庫レコードに別々に保存されているので、本社工場のものを編集対象とする
    final honsha = s.honshaItem;
    final daini = s.dainiItem;
    _noteController.text = honsha?.note ?? '';
    String editingTarget = StockProvider.locationHonsha;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocalState) {
        final targetItem = editingTarget == StockProvider.locationHonsha
            ? honsha
            : daini;
        return AlertDialog(
          title: Text(s.displayName,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('品目', s.category),
                _detailRow('規格', s.spec),
                _detailRow('単位', s.unit),
                const Divider(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _locDetailRow(
                          '本社工場',
                          DateFormatter.formatQuantity(
                              s.honshaStock, s.unit),
                          DateFormatter.formatQuantity(
                              s.honshaInitial, s.unit)),
                      const SizedBox(height: 4),
                      _locDetailRow(
                          '第二工場',
                          DateFormatter.formatQuantity(
                              s.dainiStock, s.unit),
                          DateFormatter.formatQuantity(
                              s.dainiInitial, s.unit)),
                      const Divider(height: 12),
                      _locDetailRow(
                          '合計',
                          DateFormatter.formatQuantity(
                              s.totalStock, s.unit),
                          DateFormatter.formatQuantity(
                              s.totalInitial, s.unit),
                          isTotal: true),
                    ],
                  ),
                ),
                const Divider(height: 16),
                _detailRow(
                    '本社 最終納入日',
                    DateFormatter.format(honsha?.lastDeliveryDate)),
                _detailRow(
                    '本社 最終出荷日',
                    DateFormatter.format(honsha?.lastShippingDate)),
                _detailRow(
                    '第二 最終納入日',
                    DateFormatter.format(daini?.lastDeliveryDate)),
                _detailRow(
                    '第二 最終出荷日',
                    DateFormatter.format(daini?.lastShippingDate)),
                const SizedBox(height: 12),
                // 備考対象の工場切替
                Row(
                  children: [
                    const Text('備考',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: editingTarget,
                      isDense: true,
                      items: StockProvider.locations
                          .map((l) => DropdownMenuItem(
                              value: l,
                              child:
                                  Text(l, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() {
                          editingTarget = v;
                          final newTarget =
                              v == StockProvider.locationHonsha ? honsha : daini;
                          _noteController.text = newTarget?.note ?? '';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '$editingTarget の備考を入力...',
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
              onPressed: targetItem == null
                  ? null
                  : () {
                      provider.updateNote(
                          targetItem.id,
                          _noteController.text.isEmpty
                              ? null
                              : _noteController.text);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('$editingTarget の備考を保存しました'),
                            duration: const Duration(seconds: 1)),
                      );
                    },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 40)),
              child: const Text('保存'),
            ),
          ],
        );
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
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

  Widget _locDetailRow(String loc, String current, String initial,
      {bool isTotal = false}) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(loc,
              style: TextStyle(
                  fontSize: 12,
                  color: isTotal
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ),
        Expanded(
          child: Row(
            children: [
              Text('現在庫：',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              Text(current,
                  style: TextStyle(
                      fontSize: isTotal ? 14 : 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen)),
              const SizedBox(width: 10),
              Text('初期：',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              Text(initial,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context, StockProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('在庫修正へ移動',
                  style: TextStyle(fontSize: 14)),
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
                            Text('在庫修正',
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
                  label:
                      const Text('CSV出力', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: () =>
                      _showCsvDownloadDialog(context, provider),
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
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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
