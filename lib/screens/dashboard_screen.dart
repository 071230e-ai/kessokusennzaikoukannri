import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final lowItems = provider.lowStockItems;
        final allItems = provider.stockItems;
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
                  // ヘッダーバナー
                  _buildHeader(context),

                  const SizedBox(height: 12),

                  // 在庫警告
                  if (lowItems.isNotEmpty) ...[
                    _buildSection(
                      context,
                      title: '⚠️ 在庫が少ない品目',
                      titleColor: AppTheme.warningRed,
                      child: _buildLowStockWarning(lowItems),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 在庫サマリー
                  _buildSection(
                    context,
                    title: '📦 現在の在庫状況',
                    child: _buildStockSummary(allItems),
                  ),

                  const SizedBox(height: 12),

                  // 最近の納入・出荷
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
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '最終更新: ${DateFormatter.format(DateTime.now())}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
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

  Widget _buildLowStockWarning(List<StockItem> items) {
    return Card(
      color: AppTheme.warningRedLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.warningRed, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    DateFormatter.formatQuantity(item.currentStock, item.unit),
                    style: const TextStyle(
                      color: AppTheme.warningRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildStockSummary(List<StockItem> items) {
    // カテゴリ別にグループ化
    final categories = <String, List<StockItem>>{};
    for (final item in items) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      children: categories.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ...entry.value.map((item) => _buildStockRow(item)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockRow(StockItem item) {
    final isLow = item.currentStock <= item.lowStockThreshold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.spec == '-' ? '（単品）' : item.spec,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormatter.formatQuantity(item.currentStock, item.unit),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isLow ? AppTheme.warningRed : AppTheme.primaryGreen,
              ),
            ),
          ),
          if (isLow)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.arrow_downward, color: AppTheme.warningRed, size: 14),
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
            child: Text('履歴なし', style: TextStyle(color: AppTheme.textSecondary)),
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
                children: [
                  Text(
                    DateFormatter.formatShort(r.deliveryDate),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.spec == '-' ? r.category : '${r.category}\n${r.spec}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
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
            child: Text('履歴なし', style: TextStyle(color: AppTheme.textSecondary)),
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
                children: [
                  Text(
                    DateFormatter.formatShort(r.shippingDate),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.spec == '-' ? r.category : '${r.category}\n${r.spec}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
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
