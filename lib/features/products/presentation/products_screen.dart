import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/product_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final prods = await _productService.getProducts();
    if (mounted) {
      setState(() {
        _products = prods;
        _isLoading = false;
      });
    }
  }

  void _showAddEditProductModal([Map<String, dynamic>? product]) {
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final priceCtrl = TextEditingController(text: product != null ? product['selling_price'].toString() : '');
    final descCtrl = TextEditingController(text: product?['description'] ?? '');
    final isEdit = product != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Product' : 'Add New Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Selling Price (LKR)', prefixText: 'LKR '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = Formatters.parseDouble(priceCtrl.text);
              if (name.isEmpty || price < 0) return;

              try {
                if (isEdit) {
                  await _productService.updateProduct(
                    id: product['id'] as int,
                    name: name,
                    newPrice: price,
                    description: descCtrl.text.trim(),
                  );
                } else {
                  await _productService.createProduct(
                    name: name,
                    sellingPrice: price,
                    description: descCtrl.text.trim(),
                  );
                }
                Navigator.pop(ctx);
                _loadProducts();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPriceHistory(int productId, String productName) async {
    final history = await _productService.getPriceHistory(productId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$productName - Price History'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('No price changes recorded.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final h = history[idx];
                    final oldP = (h['old_price'] as num).toDouble();
                    final newP = (h['new_price'] as num).toDouble();
                    final changedAt = h['changed_at'] as String;
                    final reason = h['reason'] ?? 'Price update';
                    return ListTile(
                      dense: true,
                      title: Text('${Formatters.currency(oldP)} → ${Formatters.currency(newP)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$reason\n${Formatters.displayDateTime(changedAt)}', style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Selling Prices'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final p = _products[idx];
                final id = p['id'] as int;
                final name = p['name'] as String;
                final price = (p['selling_price'] as num).toDouble();
                final desc = p['description'] ?? '';
                final isActive = (p['is_active'] as int) == 1;

                return Card(
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (!isActive)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.black54)),
                              ),
                          ],
                        ),
                        Text(Formatters.currency(price), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showAddEditProductModal(p),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.history, size: 14),
                              label: const Text('History', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showPriceHistory(id, name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditProductModal(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
