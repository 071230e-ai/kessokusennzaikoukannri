// 在庫修正履歴画面
//
// 新しい順に表示。同じ adjustment_group_id のレコードは一括修正扱いでグループ化。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_adjustment.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import '../utils/jst_time.dart';

class StockAdjustmentHistoryScreen extends StatelessWidget {
  const StockAdjustmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('在庫修正履歴'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, _) {
          final all = List<StockAdjustment>.from(provider.stockAdjustments);
          // 新しい順（provider は API 側で並び済みだが念のためソート）
          all.sort((a, b) => b.adjustedAt.compareTo(a.adjustedAt));

          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 48, color: AppTheme.borderColor),
                    SizedBox(height: 12),
                    Text(
                      '在庫修正の履歴がまだありません',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // adjustment_group_id ごとにグループ化（順序は最新→過去）
          final groups = <_AdjustmentGroup>[];
          final seenGroupIds = <String, int>{};
          for (final a in all) {
            final gid = a.adjustmentGroupId;
            if (seenGroupIds.containsKey(gid)) {
              groups[seenGroupIds[gid]!].adjustments.add(a);
            } else {
              seenGroupIds[gid] = groups.length;
              groups.add(_AdjustmentGroup(
                groupId: gid,
                adjustedAt: a.adjustedAt,
                location: a.location,
                adjustedBy: a.adjustedBy,
                note: a.note,
                adjustments: [a],
              ));
            }
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshAll(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              itemBuilder: (context, i) => _buildGroupCard(groups[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(_AdjustmentGroup g) {
    final iconData = g.location.contains('本社')
        ? Icons.factory_outlined
        : Icons.warehouse_outlined;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 修正日時 + 工場 + 品目数
            Row(
              children: [
                Icon(iconData, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  g.location,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${g.adjustments.length}品目',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  JstTime.formatDisplay(g.adjustedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if ((g.adjustedBy ?? '').isNotEmpty || (g.note ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if ((g.adjustedBy ?? '').isNotEmpty) ...[
                      const Icon(Icons.person_outline,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(g.adjustedBy!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                    if ((g.note ?? '').isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(g.note!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 6),
            // 品目一覧
            ...g.adjustments.map((a) => _buildItemRow(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(StockAdjustment a) {
    final diff = a.difference;
    final diffColor = diff > 0
        ? AppTheme.primaryGreen
        : (diff < 0 ? AppTheme.warningRed : AppTheme.textSecondary);
    final diffAbs = diff.abs();
    final diffStr = diffAbs == diffAbs.roundToDouble()
        ? diffAbs.toInt().toString()
        : diffAbs.toStringAsFixed(1);
    final diffSign = diff > 0 ? '+' : (diff < 0 ? '-' : '±');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              a.displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              DateFormatter.formatQuantity(a.previousStock, a.unit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward,
                size: 12, color: AppTheme.textSecondary),
          ),
          Expanded(
            flex: 3,
            child: Text(
              DateFormatter.formatQuantity(a.adjustedStock, a.unit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$diffSign$diffStr ${a.unit}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: diffColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentGroup {
  final String groupId;
  final DateTime adjustedAt;
  final String location;
  final String? adjustedBy;
  final String? note;
  final List<StockAdjustment> adjustments;

  _AdjustmentGroup({
    required this.groupId,
    required this.adjustedAt,
    required this.location,
    required this.adjustedBy,
    required this.note,
    required this.adjustments,
  });
}
