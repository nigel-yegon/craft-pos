import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductProvider provider;
  final Product? product;

  const ProductFormScreen({super.key, required this.provider, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _openingStockController;
  late TextEditingController _reorderLevelController;
  String? _selectedCategoryId;
  String? _imagePath;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _buyingPriceController = TextEditingController(
        text: p != null ? (p.costPriceMinor / 100).toString() : '');
    _sellingPriceController = TextEditingController(
        text: p != null ? (p.sellingPriceMinor / 100).toString() : '');
    _openingStockController = TextEditingController();
    _reorderLevelController = TextEditingController(
        text: p != null ? (p.reorderLevelMilli / 1000).toString() : '5');
    _selectedCategoryId = p?.categoryId;
    _imagePath = p?.imagePath;
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    final path = await widget.provider.pickAndSaveProductImage();
    if (!mounted) return;
    setState(() {
      if (path != null) _imagePath = path;
      _pickingImage = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await widget.provider.saveProduct(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      categoryId: _selectedCategoryId,
      costPriceMinor:
      ((double.tryParse(_buyingPriceController.text) ?? 0) * 100).toInt(),
      sellingPriceMinor:
      ((double.tryParse(_sellingPriceController.text) ?? 0) * 100).toInt(),
      reorderLevelMilli:
      ((double.tryParse(_reorderLevelController.text) ?? 5) * 1000).toInt(),
      openingStockMilli:
      ((double.tryParse(_openingStockController.text) ?? 0) * 1000).toInt(),
      imagePath: _imagePath,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Product image ───
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        image: _imagePath != null &&
                            File(_imagePath!).existsSync()
                            ? DecorationImage(
                          image: FileImage(File(_imagePath!)),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _pickingImage
                          ? const Center(child: CircularProgressIndicator())
                          : (_imagePath == null ||
                          !File(_imagePath!).existsSync())
                          ? const Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: AppTheme.primaryGreen,
                      )
                          : null,
                    ),
                  ),
                  if (_imagePath != null &&
                      File(_imagePath!).existsSync())
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePath = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to ${_imagePath == null ? 'add' : 'change'} photo',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(labelText: 'SKU')),
            const SizedBox(height: 12),

            // Category dropdown
            StreamBuilder<List<Category>>(
              stream: (widget.provider.db.select(widget.provider.db.categories)
                ..where((c) =>
                    c.businessId.equals(widget.provider.businessId)))
                  .watch(),
              builder: (context, snapshot) {
                final cats = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Uncategorised')),
                    ...cats.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedCategoryId = val),
                );
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyingPriceController,
                    decoration:
                    const InputDecoration(labelText: 'Buying Price (KES)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceController,
                    decoration:
                    const InputDecoration(labelText: 'Selling Price (KES)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (widget.product == null)
                  Expanded(
                    child: TextFormField(
                      controller: _openingStockController,
                      decoration:
                      const InputDecoration(labelText: 'Opening Stock'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                if (widget.product == null) const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _reorderLevelController,
                    decoration: const InputDecoration(
                        labelText: 'Low Stock Alert Level'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}