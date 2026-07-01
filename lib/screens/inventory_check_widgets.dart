// 実在庫確認（月次照合）に関する UI 群。
//
// - `InventoryCheckNotice`     ダッシュボード上部に表示する通知バナー
// - `showInventoryCheckDialog` 完了登録ダイアログ
// - `showRevokeCheckDialog`    完了取り消し確認ダイアログ
//
// 当月の未完了工場がある場合のみバナーを表示。各工場ごとに「在庫確認を開始」
// → 完了ダイアログ → 完了登録 という流れ。閉じるボタンでは消えない仕様。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_check.dart';
import '../providers/stock_provider.dart';
import '../utils/app_theme.dart';
import '../utils/jst_time.dart';
import 'inventory_check_history_screen.dart';

// =====================================================================
// 通知バナー
// =====================================================================

class InventoryCheckNotice extends StatelessWidget {
  const InventoryCheckNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        // 当月 (JST) 1日以降の判定。実装上は year/month を JST で取得した
        // 時点で「現在の対象月」が確定するので、day >= 1 は常に true。
        if (!JstTime.isOnOrAfterCurrentMonthFirst()) {
          return const SizedBox.shrink();
        }

        final (year, month) = JstTime.currentYearMonth();
        final statusMap = provider.getCurrentMonthCheckStatus();
        final past = provider.getPastUncompleted();

        final hasCurrentUncompleted =
            statusMap.values.any((c) => c == null);
        if (!hasCurrentUncompleted && past.isEmpty) {
          // 全工場完了かつ過去月も問題なし → 何も表示しない
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFFFB74D), width: 1.4),
            ),
            color: const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Color(0xFFE65100), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${JstTime.formatYearMonth(year, month)}の実在庫確認',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFBF360C)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '各工場の実在庫と、アプリ上の在庫を照合してください。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                  ),
                  const SizedBox(height: 10),
                  // 工場別の状態と操作ボタン
                  ...StockProvider.locations.map((loc) {
                    final check = statusMap[loc];
                    return _LocationStatusRow(
                      year: year,
                      month: month,
                      location: loc,
                      check: check,
                    );
                  }),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _PastUncompletedSection(past: past),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('確認履歴を見る',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFBF360C),
                        minimumSize: const Size(60, 32),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const InventoryCheckHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationStatusRow extends StatelessWidget {
  final int year;
  final int month;
  final String location;
  final InventoryCheck? check;

  const _LocationStatusRow({
    required this.year,
    required this.month,
    required this.location,
    required this.check,
  });

  @override
  Widget build(BuildContext context) {
    final completed = check != null && check!.isCompleted;
    final bgColor = completed ? const Color(0xFFE8F5E9) : Colors.white;
    final borderColor =
        completed ? AppTheme.primaryGreen : const Color(0xFFFFB74D);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? AppTheme.primaryGreen : const Color(0xFFE65100),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                if (completed) ...[
                  Text(
                    '確認済み  ${JstTime.formatDisplay(check!.checkedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  if ((check!.checkedBy ?? '').isNotEmpty)
                    Text('確認者: ${check!.checkedBy}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                ] else
                  const Text('未完了',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFFE65100))),
              ],
            ),
          ),
          if (completed)
            TextButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('取り消し', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warningRed,
                minimumSize: const Size(60, 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: () => showRevokeCheckDialog(context, check!),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.fact_check, size: 16),
              label: const Text('在庫確認を開始',
                  style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                minimumSize: const Size(120, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => showInventoryCheckDialog(
                context,
                year: year,
                month: month,
                location: location,
              ),
            ),
        ],
      ),
    );
  }
}

class _PastUncompletedSection extends StatelessWidget {
  final List<({int year, int month, String location})> past;

  const _PastUncompletedSection({required this.past});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 16, color: Color(0xFFBF360C)),
            const SizedBox(width: 6),
            Text(
              '過去の未完了が${past.length}件あります',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBF360C)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _showPastDialog(context),
              style: TextButton.styleFrom(
                  minimumSize: const Size(60, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('詳細を見る', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  void _showPastDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('過去の未完了'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: past.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFE65100), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${JstTime.formatYearMonth(p.year, p.month)} '
                          '${p.location} の在庫確認が未完了です',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side:
                              const BorderSide(color: AppTheme.primaryGreen),
                          minimumSize: const Size(70, 32),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showInventoryCheckDialog(
                            context,
                            year: p.year,
                            month: p.month,
                            location: p.location,
                          );
                        },
                        child: const Text('完了登録',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }).toList(),
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

// =====================================================================
// 在庫確認完了ダイアログ
// =====================================================================

Future<void> showInventoryCheckDialog(
  BuildContext context, {
  required int year,
  required int month,
  required String location,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InventoryCheckDialog(
      year: year,
      month: month,
      location: location,
    ),
  );
}

class _InventoryCheckDialog extends StatefulWidget {
  final int year;
  final int month;
  final String location;
  const _InventoryCheckDialog({
    required this.year,
    required this.month,
    required this.location,
  });

  @override
  State<_InventoryCheckDialog> createState() => _InventoryCheckDialogState();
}

class _InventoryCheckDialogState extends State<_InventoryCheckDialog> {
  final _checkedByCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _errorMsg;

  @override
  void dispose() {
    _checkedByCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    setState(() => _errorMsg = null);
    final by = _checkedByCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    // 確認ダイアログ
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('在庫確認の完了'),
        content: Text(
          '${widget.location}の実在庫とアプリ在庫の照合は完了しましたか？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx2, true),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(96, 40),
                backgroundColor: AppTheme.primaryGreen),
            child: const Text('確認完了'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<StockProvider>().markInventoryCheckCompleted(
            year: widget.year,
            month: widget.month,
            locationName: widget.location,
            checkedBy: by.isEmpty ? null : by,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.location}の在庫確認を完了しました'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = '保存に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.location} 在庫確認'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '対象: ${JstTime.formatYearMonth(widget.year, widget.month)} '
                      '${widget.location}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '実在庫を数えてアプリの在庫数と照合してください。\n'
                      '完了したら下のボタンから登録します。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('確認者（任意）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _checkedByCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '例：村田',
                ),
              ),
              const SizedBox(height: 12),
              const Text('備考（任意）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '例：差異なし／○○を○○kg修正',
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(_errorMsg!,
                    style: const TextStyle(
                        color: AppTheme.warningRed, fontSize: 13)),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('キャンセル')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _onConfirm,
          icon: const Icon(Icons.fact_check, size: 18),
          label: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('在庫確認完了'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 40),
              backgroundColor: AppTheme.primaryGreen),
        ),
      ],
    );
  }
}

// =====================================================================
// 取り消しダイアログ
// =====================================================================

Future<void> showRevokeCheckDialog(
    BuildContext context, InventoryCheck check) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('完了状態の取り消し'),
      content: Text(
        '${JstTime.formatYearMonth(check.targetYear, check.targetMonth)} '
        '${check.location} の\n在庫確認の完了状態を取り消しますか？\n'
        '\n取り消すと通知が再表示されます。',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(96, 40),
              backgroundColor: AppTheme.warningRed),
          child: const Text('取り消す'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  if (!context.mounted) return;
  try {
    await context.read<StockProvider>().revokeInventoryCheck(check.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${check.location} の在庫確認を未完了に戻しました'),
        backgroundColor: AppTheme.warningRed,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('取り消しに失敗しました: $e')),
    );
  }
}
