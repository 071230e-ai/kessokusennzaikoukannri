// 在庫確認履歴画面。
//
// `provider.inventoryChecks` を新しい年月順（DESC）→工場名順で表示する。
// 通知バナーの「履歴を見る」ボタンから開かれる単独画面。
// 既存のボトムナビには追加しない（タブが7つで既に混雑しているため）。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_check.dart';
import '../providers/stock_provider.dart';
import '../utils/app_theme.dart';
import '../utils/jst_time.dart';
import 'inventory_check_widgets.dart';

class InventoryCheckHistoryScreen extends StatelessWidget {
  const InventoryCheckHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '在庫確認履歴',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '更新',
            onPressed: () => context.read<StockProvider>().refreshAll(),
          ),
        ],
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, _) {
          final checks = [...provider.inventoryChecks]
            ..sort((a, b) {
              // 新しい年月が上。同じ年月なら工場名で並べる。
              final ym =
                  (b.targetYear * 100 + b.targetMonth) -
                      (a.targetYear * 100 + a.targetMonth);
              if (ym != 0) return ym;
              return a.location.compareTo(b.location);
            });

          if (checks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fact_check_outlined,
                        size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      '在庫確認の履歴がまだありません',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          // 年月ごとにグルーピングして表示
          final grouped = <String, List<InventoryCheck>>{};
          for (final c in checks) {
            final key = JstTime.formatYearMonth(c.targetYear, c.targetMonth);
            grouped.putIfAbsent(key, () => []).add(c);
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                Card(
                  color: AppTheme.backgroundGreen,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.primaryGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '完了登録された ${checks.length} 件の在庫確認履歴を表示しています。新しい年月順。',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...grouped.entries.map((e) => _MonthGroup(
                      ymLabel: e.key,
                      records: e.value,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthGroup extends StatelessWidget {
  final String ymLabel;
  final List<InventoryCheck> records;
  const _MonthGroup({required this.ymLabel, required this.records});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ymLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${records.length}件',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          ...records.map((c) => _HistoryRow(check: c)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final InventoryCheck check;
  const _HistoryRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final completed = check.isCompleted;
    final note = (check.note ?? '').trim();
    final by = (check.checkedBy ?? '').trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: completed
                      ? AppTheme.primaryGreen
                      : const Color(0xFFE65100),
                ),
                const SizedBox(width: 6),
                Text(
                  check.location,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: completed
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    completed ? '完了' : '未完了',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (completed)
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('取り消し',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.warningRed,
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () =>
                        showRevokeCheckDialog(context, check),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _kv('対象年月',
                JstTime.formatYearMonth(check.targetYear, check.targetMonth)),
            _kv('確認日時', JstTime.formatDisplay(check.checkedAt)),
            _kv('確認者', by.isEmpty ? '-' : by),
            _kv('備考', note.isEmpty ? '-' : note),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
