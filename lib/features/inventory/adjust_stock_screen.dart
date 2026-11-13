import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';

class AdjustStockScreen extends StatefulWidget {
  final ProductProvider provider;
  final Product? initialProduct;

  const AdjustStockScreen({
    super.key,
    required this.provider,
    this.initialProduct,
  });

  @override
  State<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends State<AdjustStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final _unitCostController = TextEditingController();

  Product? _selectedProduct;
  String _direction = 'add';
  String _reason = 'adjustment';
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) return;

    final deltaMilli =
        (_direction == 'add' ? 1 : -1) * (quantity * 1000).round();

    int? unitCostMinor;
    if (_direction == 'add') {
      final parsed = double.tryParse(_unitCostController.text);
      if (parsed != null && parsed >= 0) {
        unitCostMinor = (parsed * 100).toInt();
      }
    }

    setState(() => _saving = true);

    try {
      await widget.provider.adjustStock(
        productId: _selectedProduct!.id,
        deltaMilli: deltaMilli,
        reason: _reason,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        unitCostMinor: unitCostMinor,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to adjust stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Adjust Stock'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: _saving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check, color: AppTheme.inkBlack),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      // ⭐ Use a Column that fills the screen instead of a ScrollView
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedProduct == null) ...[
            // ═══ STATE 1: SEARCH & LIST ═══
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search product',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),

            // ⭐ Expanded fills the remaining space
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.inkBlack.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: StreamBuilder<List<Product>>(
                    stream: widget.provider.productsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final matches = snapshot.data!.where((p) {
                        return p.name.toLowerCase().contains(_search) ||
                            (p.sku?.toLowerCase().contains(_search) ?? false);
                      }).toList();

                      if (matches.isEmpty) {
                        return const Center(child: Text('No products match.'));
                      }

                      return ListView.separated(
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppTheme.inkBlack.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (_, index) {
                          final p = matches[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined,
                                color: AppTheme.heroGreen),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: p.sku != null
                                ? Text('SKU: ${p.sku}')
                                : null,
                            onTap: () => setState(() {
                              _selectedProduct = p;
                              _search = '';
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ] else ...[
            // ═══ STATE 2: FORM ═══
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Selected product card ───
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.softMint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.heroGreen.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                color: AppTheme.heroGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.inkBlack,
                                    ),
                                  ),
                                  Text(
                                    'Current price: KSh ${(_selectedProduct!.sellingPriceMinor / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.onLightMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.change_circle_outlined,
                                  color: AppTheme.inkBlack),
                              tooltip: 'Change product',
                              onPressed: () =>
                                  setState(() => _selectedProduct = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Direction toggle ───
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Add Stock'),
                              selected: _direction == 'add',
                              selectedColor: AppTheme.heroGreen,
                              labelStyle: TextStyle(
                                color: _direction == 'add'
                                    ? Colors.white
                                    : AppTheme.inkBlack,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _direction = 'add'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Remove Stock'),
                              selected: _direction == 'remove',
                              selectedColor: AppTheme.burntOrange,
                              labelStyle: TextStyle(
                                color: _direction == 'remove'
                                    ? Colors.white
                                    : AppTheme.inkBlack,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _direction = 'remove'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Quantity ───
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _direction == 'add'
                              ? 'Quantity to add'
                              : 'Quantity to remove',
                          suffixText: 'units',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        validator: (v) {
                          final qty = double.tryParse(v ?? '');
                          if (qty == null || qty <= 0) {
                            return 'Enter a positive quantity';
                          }
                          return null;
                        },
                      ),

                      // ─── Per-batch unit cost ───
                      if (_direction == 'add') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _unitCostController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit cost for this batch (KSh)',
                            hintText: 'e.g. 45.50',
                            prefixIcon: const Icon(Icons.attach_money),
                            helperText: _selectedProduct?.costPriceMinor != null
                                ? 'Current cost: KSh ${(_selectedProduct!.costPriceMinor / 100).toStringAsFixed(2)}'
                                : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v);
                            if (n == null || n < 0) {
                              return 'Enter a valid cost';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ─── Reason ───
                      DropdownButtonFormField<String>(
                        initialValue: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          prefixIcon: Icon(Icons.report),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'purchase',
                            child: Text(_direction == 'add'
                                ? 'Purchase / restock'
                                : 'Return to supplier'),
                          ),
                          DropdownMenuItem(
                            value: 'adjustment',
                            child: Text(_direction == 'add'
                                ? 'Stock count (found extra)'
                                : 'Stock count (found less)'),
                          ),
                          DropdownMenuItem(
                            value: 'damage',
                            child: Text(_direction == 'add'
                                ? 'Recovered from damage'
                                : 'Damaged / expired'),
                          ),
                          DropdownMenuItem(
                            value: 'return',
                            child: Text(_direction == 'add'
                                ? 'Customer return'
                                : 'Return to supplier'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                      ),
                      const SizedBox(height: 20),

                      // ─── Note ───
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: 'e.g., Received from supplier #123',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(
                              _saving ? 'Saving...' : 'Apply Adjustment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.heroGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}