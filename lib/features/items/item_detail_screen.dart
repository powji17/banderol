import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'item_form_screen.dart';
import 'items_provider.dart';

class ItemDetailScreen extends ConsumerWidget {
  final int itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  Future<void> _showQuickPriceEditDialog(
    BuildContext context,
    WidgetRef ref,
    ItemWithRelations item, {
    required bool isWholesale,
  }) async {
    final initialPrice = isWholesale ? item.wholesalePrice : item.retailPrice;
    final controller = TextEditingController(
      text: initialPrice != null ? AppFormatters.formatThousand(initialPrice) : '',
    );
    int selectedUnitId = isWholesale
        ? (item.wholesaleUnitId ?? item.retailUnitId)
        : item.retailUnitId;
    final units = ref.read(catalogProvider).units;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isWholesale ? 'Ubah Cepat Harga Grosir' : 'Ubah Cepat Harga Eceran'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandSeparatorInputFormatter()],
                  decoration: InputDecoration(
                    labelText: isWholesale ? 'Harga Grosir (Rp)' : 'Harga Eceran (Rp)',
                    prefixText: 'Rp ',
                    border: const OutlineInputBorder(),
                    helperText: isWholesale ? 'Kosongkan untuk menghapus harga grosir' : null,
                  ),
                  validator: isWholesale
                      ? AppFormatters.validateWholesalePrice
                      : AppFormatters.validateRetailPrice,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Satuan',
                    border: OutlineInputBorder(),
                  ),
                  items: units
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedUnitId = val);
                    }
                  },
                ),
              ],
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
      final parsedPrice = AppFormatters.parseRupiahInput(controller.text);
      await AppDatabase.instance.updateItem(
        id: item.id,
        name: item.name,
        categoryId: item.categoryId,
        barcode: item.barcode,
        retailPrice: isWholesale ? item.retailPrice : parsedPrice!,
        retailUnitId: isWholesale ? item.retailUnitId : selectedUnitId,
        wholesalePrice: isWholesale ? parsedPrice : item.wholesalePrice,
        wholesaleUnitId: isWholesale
            ? (parsedPrice != null ? selectedUnitId : null)
            : item.wholesaleUnitId,
      );
      await ref.read(catalogProvider.notifier).refreshAll();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ItemWithRelations item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Barang?'),
        content: Text('Apakah Anda yakin ingin menghapus "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(catalogProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);
      await AppDatabase.instance.deleteItem(item.id);
      await notifier.refreshAll();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // FR-23: Opsi Urungkan (Undo) beberapa detik setelah dihapus
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('"${item.name}" dihapus'),
          action: SnackBarAction(
            label: 'URUNGKAN',
            onPressed: () {
              notifier.restoreDeletedItem(item);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final item = catalog.allItems.where((i) => i.id == itemId).firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Barang')),
        body: const Center(child: Text('Barang tidak ditemukan.')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Barang'),
        actions: [
          IconButton(
            tooltip: 'Ubah Barang',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ItemFormScreen(editItem: item)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Nama & Kategori
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  CategoryIcons.getIcon(item.categoryIconKey),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(item.categoryName),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Kartu Harga Eceran (Ketuk untuk ubah cepat - Alur E)
          Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showQuickPriceEditDialog(
                context,
                ref,
                item,
                isWholesale: false,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HARGA ECERAN',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.touch_app, size: 16),
                            SizedBox(width: 4),
                            Text('Ketuk untuk ubah cepat', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppFormatters.formatRupiah(item.retailPrice)} / ${item.retailUnitName}',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kartu Harga Grosir (Ketuk untuk ubah cepat)
          Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showQuickPriceEditDialog(
                context,
                ref,
                item,
                isWholesale: true,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HARGA GROSIR / KARTONAN',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.touch_app, size: 16),
                            SizedBox(width: 4),
                            Text('Ketuk untuk ubah cepat', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.wholesalePrice != null
                          ? '${AppFormatters.formatRupiah(item.wholesalePrice!)} / ${item.wholesaleUnitName}'
                          : 'Belum diatur (Ketuk untuk mengisi)',
                      style: item.wholesalePrice != null
                          ? textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            )
                          : textTheme.titleMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Informasi Barcode
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.qr_code),
            title: const Text('Barcode'),
            subtitle: Text(
              item.barcode != null && item.barcode!.isNotEmpty
                  ? item.barcode!
                  : 'Tidak ada barcode',
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Tombol Aksi: Ubah, Duplikat (FR-24), Hapus (FR-23)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ItemFormScreen(editItem: item)),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Ubah Lengkap'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemFormScreen(duplicateFromItem: item),
                  ),
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Duplikat Barang'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
                onPressed: () => _confirmDelete(context, ref, item),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}