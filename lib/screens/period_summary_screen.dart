import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

/// 期間集計（入出荷集計）画面
///
/// 期間（開始日〜終了日）・保管場所（全体／本社／第二）・品目（全品目／個別）を指定し、
/// 指定期間内の納入数量・出荷使用数量・差引数量を品目別に集計表示する。
class PeriodSummaryScreen extends StatefulWidget {
  const PeriodSummaryScreen({super.key});

  @override
  State<PeriodSummaryScreen> createState() => _PeriodSummaryScreenState();
}

/// 保管場所フィルタ
enum _LocFilter { all, honsha, daini }

extension on _LocFilter {
  String get label {
    switch (this) {
      case _LocFilter.all:
        return '全体';
      case _LocFilter.honsha:
        return StockProvider.locationHonsha;
      case _LocFilter.daini:
        return StockProvider.locationDaini;
    }
  }

  /// StockProvider のフィルタ条件用ロケーション名（null=全体）
  String? get locationName {
    switch (this) {
      case _LocFilter.all:
        return null;
      case _LocFilter.honsha:
        return StockProvider.locationHonsha;
      case _LocFilter.daini:
        return StockProvider.locationDaini;
    }
  }
}

/// 1品目分の集計結果
class _Row {
  final String category;
  final String spec;
  final String unit;
  final double delivered;
  final double shipped;
  const _Row({
    required this.category,
    required this.spec,
    required this.unit,
    required this.delivered,
    required this.shipped,
  });
  double get diff => delivered - shipped;
  String get displayName => spec == '-' ? category : '$category $spec';
}

class _PeriodSummaryScreenState extends State<PeriodSummaryScreen> {
  // ---- 入力条件 ----
  late DateTime _fromDate;
  late DateTime _toDate;
  _LocFilter _location = _LocFilter.all;

  /// null = 全品目、"カテゴリ|規格" = 個別
  String? _selectedItemKey;

  /// 集計結果（"集計する" 押下後にセット）
  List<_Row>? _results;
  DateTime? _resultFrom;
  DateTime? _resultTo;
  _LocFilter? _resultLocation;
  String? _resultItemKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1); // 当月1日
    _toDate = DateTime(now.year, now.month, now.day); // 当日
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // ===== 集計条件 =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '集計条件',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildLabel('開始日 *'),
                          _buildDatePicker(_fromDate, (d) {
                            setState(() {
                              _fromDate = d;
                              if (_toDate.isBefore(_fromDate)) {
                                _toDate = _fromDate;
                              }
                            });
                          }),
                          const SizedBox(height: 12),

                          _buildLabel('終了日 *'),
                          _buildDatePicker(_toDate, (d) {
                            setState(() {
                              _toDate = d;
                              if (_fromDate.isAfter(_toDate)) {
                                _fromDate = _toDate;
                              }
                            });
                          }),
                          const SizedBox(height: 12),

                          _buildLabel('保管場所'),
                          _buildLocationSelector(),
                          const SizedBox(height: 12),

                          _buildLabel('品目'),
                          _buildItemSelector(provider),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== 集計するボタン =====
                  ElevatedButton.icon(
                    onPressed: () => _runAggregation(provider),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('集計する'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== 結果 =====
                  if (_results != null) _buildResultSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 集計条件 UI
  // =====================================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined,
              color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '期間内の納入数量・出荷使用数量・差引数量を品目別に集計します。',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
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

  Widget _buildDatePicker(DateTime current, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 12, 31),
        );
        if (picked != null) onChanged(picked);
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
                size: 18, color: AppTheme.primaryGreen),
            const SizedBox(width: 10),
            Text(
              DateFormatter.format(current),
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

  Widget _buildLocationSelector() {
    return Row(
      children: _LocFilter.values.map((loc) {
        final selected = _location == loc;
        IconData iconData;
        switch (loc) {
          case _LocFilter.all:
            iconData = Icons.public;
            break;
          case _LocFilter.honsha:
            iconData = Icons.factory_outlined;
            break;
          case _LocFilter.daini:
            iconData = Icons.warehouse_outlined;
            break;
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _location = loc),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryGreen : Colors.white,
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryGreen
                        : AppTheme.borderColor,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : AppTheme.primaryGreen),
                    const SizedBox(height: 4),
                    Text(
                      loc.label,
                      style: TextStyle(
                        fontSize: 12,
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
    );
  }

  Widget _buildItemSelector(StockProvider provider) {
    // 「全品目」+ 個別品目（19品目）
    final pairs = provider.itemPairs;
    return DropdownButtonFormField<String?>(
      initialValue: _selectedItemKey,
      decoration: const InputDecoration(hintText: '品目を選択'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('全品目'),
        ),
        ...pairs.map((p) {
          final key = '${p['category']!}|${p['spec']!}';
          final label = p['spec'] == '-'
              ? p['category']!
              : '${p['category']!} ${p['spec']!}';
          return DropdownMenuItem<String?>(value: key, child: Text(label));
        }),
      ],
      onChanged: (v) => setState(() => _selectedItemKey = v),
    );
  }

  // =====================================================================
  // 集計実行
  // =====================================================================

  void _runAggregation(StockProvider provider) {
    final loc = _location.locationName;

    // itemPairs は表示順
    final pairs = provider.itemPairs;
    final filterPairs = _selectedItemKey == null
        ? pairs
        : pairs
            .where((p) => '${p['category']!}|${p['spec']!}' == _selectedItemKey)
            .toList();

    // 終了日 23:59:59 まで含めるため、getFiltered* に渡す toDate はそのまま
    // （Provider 内部で +1日して exclusive にしているので、その日を含む）
    final dels = provider.getFilteredDeliveries(
      fromDate: _fromDate,
      toDate: _toDate,
      location: loc,
    );
    final shps = provider.getFilteredShippings(
      fromDate: _fromDate,
      toDate: _toDate,
      location: loc,
    );

    // 集計
    final rows = <_Row>[];
    for (final p in filterPairs) {
      final cat = p['category']!;
      final spec = p['spec']!;
      // 単位を解決
      final ref = provider.findStockItem(
            category: cat,
            spec: spec,
            location: StockProvider.locationHonsha,
          ) ??
          provider.findStockItem(
            category: cat,
            spec: spec,
            location: StockProvider.locationDaini,
          );
      final unit = ref?.unit ?? 'kg';

      double delivered = 0;
      for (final d in dels) {
        if (d.category == cat && d.spec == spec) {
          delivered += d.quantity;
        }
      }
      double shipped = 0;
      for (final s in shps) {
        if (s.category == cat && s.spec == spec) {
          shipped += s.quantity;
        }
      }
      rows.add(_Row(
        category: cat,
        spec: spec,
        unit: unit,
        delivered: delivered,
        shipped: shipped,
      ));
    }

    setState(() {
      _results = rows;
      _resultFrom = _fromDate;
      _resultTo = _toDate;
      _resultLocation = _location;
      _resultItemKey = _selectedItemKey;
    });
  }

  // =====================================================================
  // 集計結果 UI
  // =====================================================================

  Widget _buildResultSection() {
    final results = _results!;
    final isEmpty = results.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 集計条件サマリ
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range,
                        size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${DateFormatter.format(_resultFrom)}〜${DateFormatter.format(_resultTo)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _resultLocation == _LocFilter.all
                          ? Icons.public
                          : _resultLocation == _LocFilter.honsha
                              ? Icons.factory_outlined
                              : Icons.warehouse_outlined,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '保管場所: ${_resultLocation!.label}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _resultItemKey == null
                            ? '品目: 全品目'
                            : '品目: ${_resultItemKey!.replaceAll('|', ' ').replaceAll('-', '')}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 結果テーブル
        if (isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.search_off,
                        size: 40, color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text('対象の品目がありません',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        else
          _buildResultTable(results),

        const SizedBox(height: 12),

        // 合計（単位ごと）
        if (results.isNotEmpty) _buildUnitTotals(results),
      ],
    );
  }

  Widget _buildResultTable(List<_Row> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 5,
                    child: Text('品目',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('納入',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('出荷',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('差引',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen)),
                  ),
                ],
              ),
            ),

            // 行
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              final isLast = i == rows.length - 1;
              final diffColor = r.diff > 0
                  ? AppTheme.primaryGreen
                  : r.diff < 0
                      ? AppTheme.warningRed
                      : AppTheme.textSecondary;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(
                              color: Color(0xFFEEEEEE), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.displayName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '単位: ${r.unit}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormatter.formatQuantity(r.delivered, r.unit),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: r.delivered > 0
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormatter.formatQuantity(r.shipped, r.unit),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: r.shipped > 0
                              ? Colors.orange.shade700
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${r.diff >= 0 ? '+' : ''}${DateFormatter.formatQuantity(r.diff, r.unit)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTotals(List<_Row> rows) {
    // 単位ごとに集計
    final unitTotals = <String, _UnitTotal>{};
    for (final r in rows) {
      final t = unitTotals.putIfAbsent(r.unit, () => _UnitTotal(unit: r.unit));
      t.delivered += r.delivered;
      t.shipped += r.shipped;
    }
    if (unitTotals.isEmpty) return const SizedBox.shrink();

    // 表示順: kg → 個
    final ordered = unitTotals.values.toList()
      ..sort((a, b) {
        if (a.unit == b.unit) return 0;
        if (a.unit == 'kg') return -1;
        if (b.unit == 'kg') return 1;
        return a.unit.compareTo(b.unit);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ordered.map((t) => _buildUnitTotalCard(t)).toList(),
    );
  }

  Widget _buildUnitTotalCard(_UnitTotal t) {
    final diff = t.delivered - t.shipped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: const Color(0xFFFFFDE7),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.summarize_outlined,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '${t.unit} 合計',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTotalRow(
                  '納入数量', t.delivered, t.unit, AppTheme.primaryGreen),
              _buildTotalRow(
                  '出荷数量', t.shipped, t.unit, Colors.orange.shade700),
              const Divider(height: 14),
              _buildTotalRow(
                '差引数量',
                diff,
                t.unit,
                diff > 0
                    ? AppTheme.primaryGreen
                    : diff < 0
                        ? AppTheme.warningRed
                        : AppTheme.textSecondary,
                bold: true,
                prefix: diff >= 0 ? '+' : '',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double value,
    String unit,
    Color color, {
    bool bold = false,
    String prefix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            '$prefix${DateFormatter.formatQuantity(value, unit)}',
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitTotal {
  final String unit;
  double delivered = 0;
  double shipped = 0;
  _UnitTotal({required this.unit});
}
