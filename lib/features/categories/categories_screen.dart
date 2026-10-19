import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../items/items_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? editCategory,
  }) async {
    final nameController = TextEditingController(text: editCategory?.name ?? '');
    String selectedIconKey = editCategory?.iconKey ?? 'category';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editCategory == null ? 'Tambah Kategori' : 'Ubah Kategori'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Pilih Ikon Kategori:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryIcons.icons.entries.map((entry) {
                      final isSelected = selectedIconKey == entry.key;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIconKey = entry.key),
                        child: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          foregroundColor: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          child: Icon(entry.value),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        if (editCategory == null) {
          await AppDatabase.instance.insertCategory(
            name: nameController.text,
            iconKey: selectedIconKey,
          );
        } else {
          await AppDatabase.instance.updateCategory(
            CategoryModel(
              id: editCategory.id,
              name: editCategory.isDefaultLainnya ? 'Lainnya' : nameController.text,
              iconKey: selectedIconKey,
              sortOrder: editCategory.sortOrder,
            ),
          );
        }
        await ref.read(catalogProvider.notifier).refreshAll();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan kategori: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) async {
    try {
      await AppDatabase.instance.deleteCategory(category.id);
      await ref.read(catalogProvider.notifier).refreshAll();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      body: ListView.separated(
        itemCount: catalog.categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final cat = catalog.categories[index];
          final itemCount =
              catalog.allItems.where((i) => i.categoryId == cat.id).length;

          return ListTile(
            leading: CircleAvatar(
              child: Icon(CategoryIcons.getIcon(cat.iconKey)),
            ),
            title: Text(cat.name),
            subtitle: Text('$itemCount barang'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      _showCategoryDialog(context, ref, editCategory: cat),
                ),
                if (!cat.isDefaultLainnya)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteCategory(context, ref, cat),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
      ),
    );
  }
}