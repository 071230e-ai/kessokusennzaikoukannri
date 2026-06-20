import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import '../utils/csv_export.dart';
import 'edit_history_dialogs.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterCategory;
  String? _filterSpec;
  String? _filterLocation;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final deliveries = provider.getFilteredDeliveries(
          category: _filterCategory,
          spec: _filterSpec,
          location: _filterLocation,
          fromDate: _fromDate,
          toDate: _toDate,
        );
        final shippings = provider.getFilteredShippings(
          category: _filterCategory,
          spec: _filterSpec,
          location: _filterLocation,
          fromDate: _fromDate,
          toDate: _toDate,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text('納入履歴 (${deliveries.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.output_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('出荷・使用履歴 (${shippings.length})'),
                        ],
                      ),
                    ),
                  ],
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryGreen,
                  labelStyle:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              _buildFilterArea(provider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDeliveryList(context, deliveries, provider),
                    _buildShippingList(context, shippings, provider),
                  ],
                ),
              ),
              _buildExportBar(provider, deliveries, shippings),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterArea(StockProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          // 1段目: 保管場所
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterLocation,
                  decoration: const InputDecoration(
                    labelText: '保管場所',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('すべて')),
                    ...StockProvider.locations.map((l) => DropdownMenuItem(
                        value: l,
                        child:
                            Text(l, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _filterLocation = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 2段目: 品目・規格
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterCategory,
                  decoration: const InputDecoration(
                    labelText: '品目',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('すべて')),
                    ...provider.categories.map((c) => DropdownMenuItem(
                        value: c,
                        child:
                            Text(c, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() {
                    _filterCategory = v;
                    _filterSpec = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterSpec,
                  decoration: const InputDecoration(
                    labelText: '規格',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('すべて')),
                    ...(_filterCategory != null
                        ? provider
                            .getSpecsForCategory(_filterCategory!)
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style:
                                        const TextStyle(fontSize: 13))))
                        : []),
                  ],
                  onChanged: (v) => setState(() => _filterSpec = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildDateButton(
                      '開始日', _fromDate, (d) => setState(() => _fromDate = d))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('〜')),
              Expanded(
                  child: _buildDateButton(
                      '終了日', _toDate, (d) => setState(() => _toDate = d))),
              if (_fromDate != null ||
                  _toDate != null ||
                  _filterCategory != null ||
                  _filterSpec != null ||
                  _filterLocation != null)
                TextButton(
                  onPressed: () => setState(() {
                    _fromDate = null;
                    _toDate = null;
                    _filterCategory = null;
                    _filterSpec = null;
                    _filterLocation = null;
                  }),
                  child: const Text('クリア',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.warningRed)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(
      String label, DateTime? date, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: date != null ? AppTheme.backgroundGreen : Colors.white,
          border: Border.all(
              color: date != null
                  ? AppTheme.primaryGreen
                  : AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 14,
                color: date != null
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                date != null ? DateFormatter.format(date) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: date != null
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close,
                    size: 14, color: AppTheme.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  /// 保管場所バッジ
  Widget _locationBadge(String location) {
    final isHonsha = location == StockProvider.locationHonsha;
    final color = isHonsha ? AppTheme.primaryGreen : Colors.indigo;
    final icon = isHonsha ? Icons.factory_outlined : Icons.warehouse_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(location,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeliveryList(BuildContext context,
      List<DeliveryRecord> records, StockProvider provider) {
    if (records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 8),
            Text('納入履歴がありません',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final r = records[index];
        return _buildDeliveryCard(context, r, provider);
      },
    );
  }

  Widget _buildDeliveryCard(BuildContext context, DeliveryRecord r,
      StockProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    DateFormatter.format(r.deliveryDate),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                _locationBadge(r.location),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.spec == '-' ? r.category : '${r.category} ${r.spec}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  DateFormatter.formatQuantity(r.quantity, r.unit),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen),
                ),
              ],
            ),
            if ((r.supplier?.isNotEmpty ?? false) ||
                (r.staff?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (r.supplier?.isNotEmpty ?? false)
                    _infoChip(Icons.store_outlined, r.supplier!),
                  if (r.staff?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 8),
                    _infoChip(Icons.person_outline, r.staff!),
                  ],
                ],
              ),
            ],
            if (r.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(r.note!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      showEditDeliveryDialog(context, r, provider),
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.primaryGreen),
                  label: const Text('編集',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.primaryGreen)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(60, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () =>
                      _confirmDeleteDelivery(context, r, provider),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.warningRed),
                  label: const Text('削除',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.warningRed)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(60, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingList(BuildContext context,
      List<ShippingRecord> records, StockProvider provider) {
    if (records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 8),
            Text('出荷・使用履歴がありません',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final r = records[index];
        return _buildShippingCard(context, r, provider);
      },
    );
  }

  Widget _buildShippingCard(BuildContext context, ShippingRecord r,
      StockProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    DateFormatter.format(r.shippingDate),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                _locationBadge(r.location),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.spec == '-' ? r.category : '${r.category} ${r.spec}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  DateFormatter.formatQuantity(r.quantity, r.unit),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                ),
              ],
            ),
            if ((r.destination?.isNotEmpty ?? false) ||
                (r.staff?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (r.destination?.isNotEmpty ?? false)
                    _infoChip(Icons.location_on_outlined, r.destination!),
                  if (r.staff?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 8),
                    _infoChip(Icons.person_outline, r.staff!),
                  ],
                ],
              ),
            ],
            if (r.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(r.note!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      showEditShippingDialog(context, r, provider),
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.primaryGreen),
                  label: const Text('編集',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.primaryGreen)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(60, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () =>
                      _confirmDeleteShipping(context, r, provider),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.warningRed),
                  label: const Text('削除',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.warningRed)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(60, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 2),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  void _confirmDeleteDelivery(BuildContext context, DeliveryRecord r,
      StockProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text(
          '${DateFormatter.format(r.deliveryDate)} の納入記録\n'
          '【${r.location}】\n'
          '${r.spec == '-' ? r.category : '${r.category} ${r.spec}'}\n'
          '${DateFormatter.formatQuantity(r.quantity, r.unit)}\n\nを削除しますか？\n在庫数も自動で再計算されます。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteDelivery(r.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('納入記録を削除しました'),
                      backgroundColor: AppTheme.warningRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteShipping(BuildContext context, ShippingRecord r,
      StockProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text(
          '${DateFormatter.format(r.shippingDate)} の出荷・使用記録\n'
          '【${r.location}】\n'
          '${r.spec == '-' ? r.category : '${r.category} ${r.spec}'}\n'
          '${DateFormatter.formatQuantity(r.quantity, r.unit)}\n\nを削除しますか？\n在庫数も自動で再計算されます。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteShipping(r.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('出荷・使用記録を削除しました'),
                      backgroundColor: AppTheme.warningRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar(StockProvider provider,
      List<DeliveryRecord> deliveries, List<ShippingRecord> shippings) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('CSV出力', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
                minimumSize: const Size(0, 48),
              ),
              onPressed: () {
                final csv = _tabController.index == 0
                    ? CsvExport.generateDeliveryCsv(deliveries)
                    : CsvExport.generateShippingCsv(shippings);
                final title = _tabController.index == 0
                    ? '納入履歴 CSV'
                    : '出荷・使用履歴 CSV';
                _showCsvDialog(context, csv, title);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCsvDialog(BuildContext context, String csv, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
}
