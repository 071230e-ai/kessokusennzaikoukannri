// 「在庫修正」画面（旧 InitialStockScreen をリネーム動作に変更）。
//
// 変更概要:
//  - 最初に工場を選択（本社工場 / 第二工場）
//  - その工場の全品目を [品目名 | アプリ在庫 | 実在庫入力 | 差異] で一覧表示
//  - 未入力の品目は修正対象外
//  - 「現在庫をすべて入力欄へコピー」ボタン
//  - 「在庫を修正する」ボタン → 確認ダイアログ → POST /api/stock-adjustments
//  - 修正日時は保存完了時点の JST（サーバ側で保存前に client 送信、または server で補完）
//  - 保存は D1 batch により atomic

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';
import 'stock_adjustment_history_screen.dart';

class InitialStockScreen extends StatefulWidget {
  const InitialStockScreen({super.key});

  @override
  State<InitialStockScreen> createState() => _InitialStockScreenState();
}

class _InitialStockScreenState extends State<InitialStockScreen> {
  /// 選択中の工場（未選択 = null）
  String? _selectedLocation;

  /// 各品目IDに対応する TextEditingController
  final Map<String, TextEditingController> _controllers = {};

  /// 現在の入力値（差異表示用）
  final Map<String, String> _inputValues = {};

  /// 修正者・備考
  final TextEditingController _adjustedByController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _adjustedByController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 選択中の工場が変わったらコントローラを再初期化
  void _ensureControllers(List<StockItem> items) {
    // 既存のうち、現在の対象品目に無いものは残しても害はない
    for (final item in items) {
      if (!_controllers.containsKey(item.id)) {
        final ctrl = TextEditingController(text: '');
        ctrl.addListener(() {
          setState(() {
            _inputValues[item.id] = ctrl.text;
          });
        });
        _controllers[item.id] = ctrl;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: _selectedLocation == null
              ? _buildFactoryPicker(context, provider)
              : _buildAdjustmentBody(context, provider),
        );
      },
    );
  }

  // =========================================================================
  // 1. 工場選択画面
  // =========================================================================
  Widget _buildFactoryPicker(BuildContext context, StockProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '修正対象の工場を選択してください',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...StockProvider.locations.map((loc) {
                  final icon = loc == StockProvider.locationHonsha
                      ? Icons.factory_outlined
                      : Icons.warehouse_outlined;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedLocation = loc;
                          // 選択時に入力状態をクリア
                          for (final c in _controllers.values) {
                            c.text = '';
                          }
                          _inputValues.clear();
                        });
                      },
                      icon: Icon(icon, size: 22),
                      label: Text(
                        loc,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 履歴画面へのリンク
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockAdjustmentHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('在庫修正履歴を見る'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune, color: AppTheme.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '在庫修正',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'アプリ上の在庫数と実際の在庫数に差異が生じた場合、実在庫を一括入力して現在庫を修正できます。\n'
            '修正日時以降の納入・出荷のみが、以降の現在庫計算へ反映されます。\n'
            '過去の履歴自体は削除されません。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryGreen,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. 修正入力画面（工場選択後）
  // =========================================================================
  Widget _buildAdjustmentBody(BuildContext context, StockProvider provider) {
    final loc = _selectedLocation!;
    final items = provider.getStockItemsByLocation(loc);
    _ensureControllers(items);

    return Column(
      children: [
        // 選択中工場ヘッダー
        _buildLocationHeader(loc),

        // アクションボタン群
        _buildActionButtons(items),

        // テーブルヘッダー
        _buildTableHeader(),

        // 品目一覧
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            itemBuilder: (context, index) => _buildItemRow(items[index]),
          ),
        ),

        // 修正者・備考 + 保存ボタン
        _buildSaveArea(context, provider, items),
      ],
    );
  }

  Widget _buildLocationHeader(String loc) {
    final iconData = loc == StockProvider.locationHonsha
        ? Icons.factory_outlined
        : Icons.warehouse_outlined;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(iconData, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            loc,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      _selectedLocation = null;
                      for (final c in _controllers.values) {
                        c.text = '';
                      }
                      _inputValues.clear();
                    });
                  },
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('工場選択へ戻る', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(List<StockItem> items) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(() {
                        for (final item in items) {
                          final ctrl = _controllers[item.id];
                          if (ctrl == null) continue;
                          ctrl.text =
                              DateFormatter.quantityStr(item.currentStock);
                          _inputValues[item.id] = ctrl.text;
                        }
                      });
                    },
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text(
                '現在庫をすべて入力欄へコピー',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      for (final item in items) {
                        _controllers[item.id]?.text = '';
                      }
                      _inputValues.clear();
                    });
                  },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('クリア', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: const [
          Expanded(
            flex: 4,
            child: Text('品目名',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text('アプリ在庫',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                )),
          ),
          Expanded(
            flex: 4,
            child: Text('実在庫入力',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text('差異',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(StockItem item) {
    final ctrl = _controllers[item.id];
    if (ctrl == null) return const SizedBox.shrink();

    // タイワイヤは整数のみ許容
    final bool integerOnly = item.category.contains('タイワイヤ');

    // 差異計算
    final input = _inputValues[item.id] ?? ctrl.text;
    final trimmed = input.trim();
    double? entered;
    if (trimmed.isNotEmpty) {
      entered = double.tryParse(trimmed);
    }
    final hasInput = entered != null && entered >= 0;
    final diff = hasInput ? entered - item.currentStock : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 品目名
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (item.spec != '-')
                    Text(
                      item.spec,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // アプリ在庫
            Expanded(
              flex: 3,
              child: Text(
                DateFormatter.formatQuantity(item.currentStock, item.unit),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // 実在庫入力
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: !integerOnly,
                  ),
                  inputFormatters: [
                    if (integerOnly)
                      FilteringTextInputFormatter.digitsOnly
                    else
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                  ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                  decoration: InputDecoration(
                    hintText: '未入力',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.borderColor,
                    ),
                    suffixText: item.unit,
                    suffixStyle: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FBF9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            // 差異
            Expanded(
              flex: 3,
              child: Text(
                _formatDiff(diff, item.unit),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _diffColor(diff),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDiff(double? diff, String unit) {
    if (diff == null) return '-';
    final abs = diff.abs();
    final numStr = abs == abs.roundToDouble()
        ? abs.toInt().toString()
        : abs.toStringAsFixed(1);
    if (diff > 0) return '+$numStr $unit';
    if (diff < 0) return '-$numStr $unit';
    return '±0 $unit';
  }

  Color _diffColor(double? diff) {
    if (diff == null) return AppTheme.textSecondary;
    if (diff > 0) return AppTheme.primaryGreen;
    if (diff < 0) return AppTheme.warningRed;
    return AppTheme.textSecondary;
  }

  Widget _buildSaveArea(
    BuildContext context,
    StockProvider provider,
    List<StockItem> items,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 修正者・備考
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adjustedByController,
                  decoration: InputDecoration(
                    labelText: '修正者（任意）',
                    labelStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: '備考（例: 月初実在庫確認）',
                    labelStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _onSavePressed(provider, items),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text(
              '在庫を修正する',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 保存処理
  // =========================================================================
  Future<void> _onSavePressed(
    StockProvider provider,
    List<StockItem> items,
  ) async {
    if (_isSaving) return; // 二重送信ガード

    final loc = _selectedLocation;
    if (loc == null) {
      _showError('工場が選択されていません');
      return;
    }

    // バリデーション & 対象品目収集
    final entries = <({String stockItemId, double adjustedStock, StockItem item})>[];
    for (final item in items) {
      final ctrl = _controllers[item.id];
      if (ctrl == null) continue;
      final text = ctrl.text.trim();
      if (text.isEmpty) continue; // 未入力 = 対象外

      final val = double.tryParse(text);
      if (val == null) {
        _showError('${item.displayName} の入力値が数値ではありません');
        return;
      }
      if (val < 0) {
        _showError('${item.displayName} の入力値がマイナスです');
        return;
      }
      if (!val.isFinite) {
        _showError('${item.displayName} の入力値が不正です');
        return;
      }
      // タイワイヤは整数のみ
      if (item.category.contains('タイワイヤ') && val != val.roundToDouble()) {
        _showError('${item.displayName} は整数のみ入力できます');
        return;
      }
      entries.add((
        stockItemId: item.id,
        adjustedStock: val,
        item: item,
      ));
    }

    if (entries.isEmpty) {
      _showError('1品目以上の実在庫を入力してください');
      return;
    }

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningRed, size: 22),
            const SizedBox(width: 8),
            Text('$loc の在庫を修正'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$loc の在庫を修正します。\n'
                'この修正日時以前の納入・出荷は、現在庫の計算対象外になります。\n'
                'よろしいですか？',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text('修正対象: ${entries.length}品目',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              ...entries.take(10).map((e) {
                final diff = e.adjustedStock - e.item.currentStock;
                final diffStr = _formatDiff(diff, e.item.unit);
                return Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '・${e.item.displayName}: '
                    '${DateFormatter.formatQuantity(e.item.currentStock, e.item.unit)}'
                    ' → ${DateFormatter.formatQuantity(e.adjustedStock, e.item.unit)}'
                    '  ($diffStr)',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }),
              if (entries.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('...ほか ${entries.length - 10} 品目',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 40),
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('在庫を修正する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await provider.saveBulkAdjustments(
        locationName: loc,
        items: entries
            .map((e) => (
                  stockItemId: e.stockItemId,
                  adjustedStock: e.adjustedStock,
                ))
            .toList(),
        adjustedBy: _adjustedByController.text.trim().isEmpty
            ? null
            : _adjustedByController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      // 成功: 入力欄クリア + スナックバー
      if (!mounted) return;
      setState(() {
        for (final c in _controllers.values) {
          c.text = '';
        }
        _inputValues.clear();
        _adjustedByController.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('$loc の在庫を修正しました'),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } on ApiException catch (e) {
      _showError('保存に失敗しました: ${e.message}');
    } catch (e) {
      _showError('保存に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppTheme.warningRed,
      ),
    );
  }
}
