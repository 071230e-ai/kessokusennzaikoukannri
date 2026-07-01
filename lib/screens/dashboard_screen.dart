import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import 'inventory_check_widgets.dart';
import 'inventory_check_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final summaries = provider.stockSummaries;
        final recentDeliveries = provider.deliveryRecords.take(5).toList();
        final recentShippings = provider.shippingRecords.take(5).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: RefreshIndicator(
            onRefresh: () async {},
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  const InventoryCheckNotice(),
                  _buildSection(
                    context,
                    title: '📦 現在の在庫状況（本社／第二／合計）',
                    child: _buildStockSummary(summaries),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSection(
                          context,
                          title: '🚚 最近の納入',
                          child: _buildRecentDeliveries(recentDeliveries),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSection(
                          context,
                          title: '📤 最近の出荷',
                          child: _buildRecentShippings(recentShippings),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.headerBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '村田鉄筋㈱',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 2),
          const Text(
            '在庫管理システム',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '最終更新: ${DateFormatter.format(DateTime.now())}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(50, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.fact_check_outlined,
                    size: 14, color: Colors.white70),
                label: const Text('在庫確認履歴',
                    style:
                        TextStyle(fontSize: 11, color: Colors.white70)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const InventoryCheckHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: titleColor ?? AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildStockSummary(List<StockSummary> summaries) {
    // カテゴリ別にグループ化
    final byCategory = <String, List<StockSummary>>{};
    for (final s in summaries) {
      byCategory.putIfAbsent(s.category, () => []).add(s);
    }

    return Column(
      children: byCategory.entries.map((entry) {
        // カテゴリ計（本社、第二、合計）
        double catHonsha = 0, catDaini = 0;
        String unit = 'kg';
        for (final s in entry.value) {
          catHonsha += s.honshaStock;
          catDaini += s.dainiStock;
          unit = s.unit;
        }
        final catTotal = catHonsha + catDaini;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '小計 ${DateFormatter.formatQuantity(catTotal, unit)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 行ヘッダー
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 3,
                          child: Text('規格',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary))),
                      Expanded(
                          flex: 2,
                          child: Text('本社工場',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary))),
                      Expanded(
                          flex: 2,
                          child: Text('第二工場',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary))),
                      Expanded(
                          flex: 2,
                          child: Text('合計',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary))),
                    ],
                  ),
                ),
                const Divider(height: 6),
                ...entry.value.map((s) => _buildSummaryDataRow(s)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryDataRow(StockSummary s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              s.spec == '-' ? '（単品）' : s.spec,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
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
          Expanded(
            flex: 2,
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
          Expanded(
            flex: 2,
            child: Text(
              DateFormatter.formatQuantity(s.totalStock, s.unit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveries(List<DeliveryRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('履歴なし',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: records.map((r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.formatShort(r.deliveryDate),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.location,
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          r.spec == '-'
                              ? r.category
                              : '${r.category} ${r.spec}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormatter.formatQuantity(r.quantity, r.unit),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentShippings(List<ShippingRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('履歴なし',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: records.map((r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.formatShort(r.shippingDate),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.location,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          r.spec == '-'
                              ? r.category
                              : '${r.category} ${r.spec}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormatter.formatQuantity(r.quantity, r.unit),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
