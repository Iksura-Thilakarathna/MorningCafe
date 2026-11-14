import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../ingredients/data/ingredient_service.dart';
import '../../products/data/product_service.dart';
import '../data/recipe_service.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final ProductService _productService = ProductService();
  final RecipeService _recipeService = RecipeService();
  final IngredientService _ingredientService = IngredientService();

  List<Map<String, dynamic>> _products = [];
  Map<int, Map<String, dynamic>> _activeVersions = {};
  Map<int, List<Map<String, dynamic>>> _recipeItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllRecipes();
  }

  Future<void> _loadAllRecipes() async {
    setState(() => _isLoading = true);
    final prods = await _productService.getProducts();
    final versions = <int, Map<String, dynamic>>{};
    final itemsMap = <int, List<Map<String, dynamic>>>{};

    for (final p in prods) {
      final pid = p['id'] as int;
      final recipe = await _recipeService.getRecipeForProduct(pid);
      if (recipe != null) {
        final ver = await _recipeService.getActiveRecipeVersion(recipe['id'] as int);
        if (ver != null) {
          final vid = ver['id'] as int;
          versions[pid] = ver;
          final items = await _recipeService.getRecipeItems(vid);
          itemsMap[pid] = items;
        }
      }
    }

    if (mounted) {
      setState(() {
        _products = prods;
        _activeVersions = versions;
        _recipeItems = itemsMap;
        _isLoading = false;
      });
    }
  }

  void _showEditRecipeDialog(int productId, String productName) async {
    final allIngredients = await _ingredientService.getIngredients(activeOnly: true);
    final currentItems = _recipeItems[productId] ?? [];
    final recipe = await _recipeService.getRecipeForProduct(productId);
    if (recipe == null) return;

    final itemsToEdit = currentItems.map((it) {
      return {
        'ingredient_id': it['ingredient_id'] as int,
        'quantity': (it['quantity'] as num).toDouble(),
        'unit': it['unit'] as String,
      };
    }).toList();

    DateTime effectiveDate = DateTime.now();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configure Recipe: $productName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Changes save as a new version. Historical sales preserve previous versions.', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    const Divider(height: 20),
                    ...itemsToEdit.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final it = entry.value;
                      final ingId = it['ingredient_id'] as int;
                      final ing = allIngredients.firstWhere((i) => i['id'] == ingId, orElse: () => {'name': 'Item $ingId', 'measurement_unit': 'units'});

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(ing['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: it['quantity'].toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  suffixText: ing['measurement_unit'],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (v) {
                                  it['quantity'] = Formatters.parseDouble(v);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                              onPressed: () {
                                setModalState(() => itemsToEdit.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Ingredient to Recipe'),
                      onPressed: () {
                        if (allIngredients.isNotEmpty) {
                          setModalState(() {
                            itemsToEdit.add({
                              'ingredient_id': allIngredients.first['id'] as int,
                              'quantity': 1.0,
                              'unit': allIngredients.first['measurement_unit'] as String,
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Save as New Recipe Version', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (itemsToEdit.isEmpty) return;
                          await _recipeService.createNewRecipeVersion(
                            recipeId: recipe['id'] as int,
                            items: itemsToEdit,
                            effectiveFrom: Formatters.date(effectiveDate),
                            notes: 'Updated recipe for $productName',
                          );
                          Navigator.pop(ctx);
                          _loadAllRecipes();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Recipes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, idx) {
                final p = _products[idx];
                final pid = p['id'] as int;
                final name = p['name'] as String;
                final ver = _activeVersions[pid];
                final items = _recipeItems[pid] ?? [];

                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (ver != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Version ${ver['version_number']}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        if (ver != null) ...[
                          const SizedBox(height: 2),
                          Text('Effective From: ${ver['effective_from']}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        ],
                        const Divider(height: 20),
                        if (items.isEmpty)
                          const Text('No ingredients configured.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))
                        else
                          ...items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(it['ingredient_name'], style: const TextStyle(fontSize: 13)),
                                  Text(
                                    Formatters.quantity(it['quantity'], it['unit']),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.edit, size: 15),
                            label: const Text('Edit Recipe Formulation'),
                            onPressed: () => _showEditRecipeDialog(pid, name),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
