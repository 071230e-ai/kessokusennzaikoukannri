import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

class ShippingRegisterScreen extends StatefulWidget {
  const ShippingRegisterScreen({super.key});

  @override
  State<ShippingRegisterScreen> createState() => _ShippingRegisterScreenState();
}

class _ShippingRegisterScreenState extends State<ShippingRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedSpec;
  StockItem? _selectedItem;
  final _quantityCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _destinationCtrl.dispose();
    _staffCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories;
        final specs = _selectedCategory != null
            ? provider.getSpecsForCategory(_selectedCategory!)
            : <String>[];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 説明カード
                      _buildInfoCard(),
                      const SizedBox(height: 16),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 出荷・使用日
                              _buildLabel('出荷・使用日 *'),
                              _buildDatePicker(),
                              const SizedBox(height: 16),

                              // 品目
                              _buildLabel('品目 *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(hintText: '品目を選択'),
                                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) => setState(() {
                                  _selectedCategory = v;
                                  _selectedSpec = null;
                                  _selectedItem = null;
                                }),
                                validator: (v) => v == null ? '品目を選択してください' : null,
                              ),
                              const SizedBox(height: 16),

                              // 規格・長さ
                              _buildLabel('規格・長さ *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSpec,
                                decoration: const InputDecoration(
                                  hintText: '品目を先に選択してください',
                                ),
                                items: specs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: _selectedCategory == null
                                    ? null
                                    : (v) {
                                        setState(() => _selectedSpec = v);
                                        if (v != null && _selectedCategory != null) {
                                          _selectedItem = provider.stockItems.firstWhere(
                                            (i) => i.category == _selectedCategory && i.spec == v,
                                          );
                                        }
                                      },
                                validator: (v) => v == null ? '規格・長さを選択してください' : null,
                              ),

                              if (_selectedItem != null) ...[
                                const SizedBox(height: 8),
                                _buildCurrentStockBadge(_selectedItem!),
                              ],

                              const SizedBox(height: 16),

                              // 数量
                              _buildLabel('数量 *'),
                              TextFormField(
                                controller: _quantityCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: _selectedItem?.unit ?? '',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return '数量を入力してください';
                                  final n = double.tryParse(v);
                                  if (n == null) return '数値を入力してください';
                                  if (n < 0) return '0以上の値を入力してください';
                                  if (_selectedItem != null && n > _selectedItem!.currentStock) {
                                    return '在庫数を超えています（現在庫: ${DateFormatter.formatQuantity(_selectedItem!.currentStock, _selectedItem!.unit)}）';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // 出荷先・使用場所
                              _buildLabel('出荷先・使用場所'),
                              TextFormField(
                                controller: _destinationCtrl,
                                decoration: const InputDecoration(hintText: '出荷先や使用場所を入力'),
                              ),
                              const SizedBox(height: 16),

                              // 担当者
                              _buildLabel('担当者'),
                              TextFormField(
                                controller: _staffCtrl,
                                decoration: const InputDecoration(hintText: '担当者名を入力'),
                              ),
                              const SizedBox(height: 16),

                              // 備考
                              _buildLabel('備考'),
                              TextFormField(
                                controller: _noteCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: '備考を入力',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 登録ボタン
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submit(provider),
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.output_rounded),
                        label: const Text('出荷・使用を登録する'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.orange.shade700,
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('フォームをリセット'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: const Row(
        children: [
          Icon(Icons.output_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '出荷・使用情報を入力してください。登録後、自動で在庫数から減算されます。',
              style: TextStyle(fontSize: 13, color: Colors.orange),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedDate = picked);
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
            const Icon(Icons.calendar_today, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              DateFormatter.format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStockBadge(StockItem item) {
    final isLow = item.currentStock <= item.lowStockThreshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLow ? AppTheme.warningRedLight : AppTheme.backgroundGreen,
        borderRadius: BorderRadius.circular(6),
        border: isLow ? Border.all(color: AppTheme.warningRed) : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: isLow ? AppTheme.warningRed : AppTheme.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            '現在庫: ${DateFormatter.formatQuantity(item.currentStock, item.unit)}',
            style: TextStyle(
              fontSize: 13,
              color: isLow ? AppTheme.warningRed : AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isLow) ...[
            const SizedBox(width: 8),
            const Text('⚠️ 在庫少', style: TextStyle(fontSize: 12, color: AppTheme.warningRed)),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(StockProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) return;

    final qty = double.tryParse(_quantityCtrl.text);
    if (qty == null || qty < 0) return;

    setState(() => _isSubmitting = true);

    final success = await provider.addShipping(
      stockItemId: _selectedItem!.id,
      shippingDate: _selectedDate,
      quantity: qty,
      destination: _destinationCtrl.text.isEmpty ? null : _destinationCtrl.text,
      staff: _staffCtrl.text.isEmpty ? null : _staffCtrl.text,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedItem!.displayName} を ${DateFormatter.formatQuantity(qty, _selectedItem!.unit)} 出荷・使用登録しました'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        _resetForm();
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: AppTheme.warningRed),
                SizedBox(width: 8),
                Text('在庫不足', style: TextStyle(color: AppTheme.warningRed)),
              ],
            ),
            content: Text(
              '在庫数を超えています。\n現在庫: ${DateFormatter.formatQuantity(_selectedItem!.currentStock, _selectedItem!.unit)}\n入力数量: ${DateFormatter.formatQuantity(qty, _selectedItem!.unit)}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 40),
                  backgroundColor: AppTheme.warningRed,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCategory = null;
      _selectedSpec = null;
      _selectedItem = null;
    });
    _quantityCtrl.clear();
    _destinationCtrl.clear();
    _staffCtrl.clear();
    _noteCtrl.clear();
  }
}
