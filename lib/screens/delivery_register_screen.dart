import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../models/stock_item.dart';
import '../utils/app_theme.dart';
import '../utils/date_formatter.dart';

class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({super.key});

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  String? _selectedLocation;
  String? _selectedCategory;
  String? _selectedSpec;
  StockItem? _selectedItem;
  final _quantityCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _supplierCtrl.dispose();
    _staffCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 場所・カテゴリ・規格が揃ったら該当の StockItem を解決
  void _resolveSelectedItem(StockProvider provider) {
    if (_selectedLocation != null &&
        _selectedCategory != null &&
        _selectedSpec != null) {
      _selectedItem = provider.findStockItem(
        category: _selectedCategory!,
        spec: _selectedSpec!,
        location: _selectedLocation!,
      );
    } else {
      _selectedItem = null;
    }
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
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 納入日
                              _buildLabel('納入日 *'),
                              _buildDatePicker(),
                              const SizedBox(height: 16),

                              // 保管場所
                              _buildLabel('保管場所 *'),
                              _buildLocationSelector(provider),
                              const SizedBox(height: 16),

                              // 品目
                              _buildLabel('品目 *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                    hintText: '品目を選択'),
                                items: categories
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _selectedCategory = v;
                                  _selectedSpec = null;
                                  _resolveSelectedItem(provider);
                                }),
                                validator: (v) =>
                                    v == null ? '品目を選択してください' : null,
                              ),
                              const SizedBox(height: 16),

                              // 規格・長さ
                              _buildLabel('規格・長さ *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSpec,
                                decoration: const InputDecoration(
                                  hintText: '品目を先に選択してください',
                                ),
                                items: specs
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: _selectedCategory == null
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _selectedSpec = v;
                                          _resolveSelectedItem(provider);
                                        });
                                      },
                                validator: (v) =>
                                    v == null ? '規格・長さを選択してください' : null,
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: _selectedItem?.unit ?? '',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '数量を入力してください';
                                  }
                                  final n = double.tryParse(v);
                                  if (n == null) return '数値を入力してください';
                                  if (n < 0) return '0以上の値を入力してください';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // 仕入先
                              _buildLabel('仕入先'),
                              TextFormField(
                                controller: _supplierCtrl,
                                decoration: const InputDecoration(
                                    hintText: '仕入先を入力'),
                              ),
                              const SizedBox(height: 16),

                              _buildLabel('担当者'),
                              TextFormField(
                                controller: _staffCtrl,
                                decoration: const InputDecoration(
                                    hintText: '担当者名を入力'),
                              ),
                              const SizedBox(height: 16),

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

                      ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(provider),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_circle_outline),
                        label: const Text('納入を登録する'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: AppTheme.primaryGreen,
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
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGreen),
      ),
      child: const Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              color: AppTheme.primaryGreen, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '納入情報を入力してください。保管場所別に在庫数へ反映されます。',
              style: TextStyle(fontSize: 13, color: AppTheme.primaryGreen),
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

  Widget _buildLocationSelector(StockProvider provider) {
    return FormField<String>(
      initialValue: _selectedLocation,
      validator: (v) => (v == null || v.isEmpty) ? '保管場所を選択してください' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: StockProvider.locations.map((loc) {
              final selected = _selectedLocation == loc;
              final iconData = loc == StockProvider.locationHonsha
                  ? Icons.factory_outlined
                  : Icons.warehouse_outlined;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLocation = loc;
                        _resolveSelectedItem(provider);
                      });
                      field.didChange(loc);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryGreen
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryGreen
                              : AppTheme.borderColor,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            loc,
                            style: TextStyle(
                              fontSize: 14,
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
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(field.errorText!,
                  style: const TextStyle(
                      color: AppTheme.warningRed, fontSize: 12)),
            ),
        ],
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
            const Icon(Icons.calendar_today,
                size: 18, color: AppTheme.primaryGreen),
            const SizedBox(width: 10),
            Text(
              DateFormatter.format(_selectedDate),
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

  Widget _buildCurrentStockBadge(StockItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGreen,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 6),
          Text(
            '${item.location} の現在庫: ${DateFormatter.formatQuantity(item.currentStock, item.unit)}',
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold),
          ),
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

    await provider.addDelivery(
      stockItemId: _selectedItem!.id,
      deliveryDate: _selectedDate,
      quantity: qty,
      supplier: _supplierCtrl.text.isEmpty ? null : _supplierCtrl.text,
      staff: _staffCtrl.text.isEmpty ? null : _staffCtrl.text,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_selectedItem!.location} ${_selectedItem!.displayName} を ${DateFormatter.formatQuantity(qty, _selectedItem!.unit)} 納入登録しました'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 3),
        ),
      );
      _resetForm();
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedLocation = null;
      _selectedCategory = null;
      _selectedSpec = null;
      _selectedItem = null;
    });
    _quantityCtrl.clear();
    _supplierCtrl.clear();
    _staffCtrl.clear();
    _noteCtrl.clear();
  }
}
