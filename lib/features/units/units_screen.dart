import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../items/items_provider.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  Future<void> _showUnitDialog(
    BuildContext context,
    WidgetRef ref, {
    UnitModel? editUnit,
  }) async {
    final controller = TextEditingController(text: editUnit?.name ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editUnit == null ? 'Tambah Satuan' : 'Ubah Satuan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Satuan (mis. renceng, ikat)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true && controller.text.trim().isNotEmpty) {
      try {
        if (editUnit == null) {
          await AppDatabase.instance.insertUnit(controller.text.trim());
        } else {
          await AppDatabase.instance.updateUnit(editUnit.id, controller.text.trim());
        }
        await ref.read(catalogProvider.notifier).refreshAll();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan satuan: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Satuan')),
      body: ListView.separated(
        itemCount: catalog.units.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final unit = catalog.units[index];
          return ListTile(
            title: Text(unit.name),
            subtitle: Text(unit.isDefault ? 'Satuan bawaan' : 'Satuan tambahan'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showUnitDialog(context, ref, editUnit: unit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    try {
                      await AppDatabase.instance.deleteUnit(unit.id);
                      await ref.read(catalogProvider.notifier).refreshAll();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUnitDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Satuan'),
      ),
    );
  }
}