import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/brand_logo.dart';
import '../backup/settings_backup_screen.dart';
import '../categories/categories_screen.dart';
import '../units/units_screen.dart';
import 'barcode_scanner_screen.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';
import 'items_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scannedCode == null || !mounted) return;

    final existing = await AppDatabase.instance.findItemByBarcode(scannedCode);
    if (!mounted) return;

    if (existing != null) {
      // Alur B.3: Jika barang ditemukan, detailnya terbuka
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: existing.id)),
      );
    } else {
      // Alur B.3 & FR-14: Jika tidak ditemukan, tawarkan tambah barang dengan barcode terisi
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Barang Belum Terdaftar'),
          content: Text(
            'Barcode "$scannedCode" tidak ditemukan di katalog.\n\nIngin menambah barang baru dengan barcode ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang Dengan Barcode Ini'),
            ),
          ],
        ),
      );

      if (shouldAdd == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemFormScreen(initialBarcode: scannedCode),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final results = catalog.filteredItems;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 28),
            SizedBox(width: 10),
            Text(
              'Banderol',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kelola Kategori',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Kelola Satuan',
            icon: const Icon(Icons.straighten_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnitsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan & Backup CSV',
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsBackupScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Kolom Pencarian langsung aktif saat aplikasi dibuka (FR-10)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (val) => ref.read(catalogProvider.notifier).setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Ketik nama barang atau barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (catalog.searchQuery.isNotEmpty)
                      IconButton(
                        tooltip: 'Bersihkan pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(catalogProvider.notifier).setSearchQuery('');
                          _searchFocusNode.requestFocus();
                        },
                      ),
                    IconButton(
                      tooltip: 'Scan Barcode',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _handleBarcodeScan,
                    ),
                  ],
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Baris Chip Kategori (FR-15)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: catalog.categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = catalog.selectedCategoryId == null;
                  return FilterChip(
                    label: Text('Semua (${catalog.allItems.length})'),
                    selected: isAllSelected,
                    onSelected: (_) =>
                        ref.read(catalogProvider.notifier).setCategoryFilter(null),
                  );
                }
                final category = catalog.categories[index - 1];
                final isSelected = catalog.selectedCategoryId == category.id;
                return FilterChip(
                  avatar: Icon(
                    CategoryIcons.getIcon(category.iconKey),
                    size: 18,
                  ),
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (_) =>
                      ref.read(catalogProvider.notifier).setCategoryFilter(category.id),
                );
              },
            ),
          ),

          const Divider(height: 8),

          // Daftar Hasil Barang
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 56,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            catalog.allItems.isEmpty
                                ? 'Belum ada barang di katalog.\nKetuk tombol + Barang di bawah untuk mulai mencatat.'
                                : 'Barang tidak ditemukan untuk pencarian ini.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return _ItemResultTile(
                        item: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(itemId: item.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ItemFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Barang'),
      ),
    );
  }
}

/// Susunan baris hasil pencarian sesuai Bab 12 PRD
class _ItemResultTile extends StatelessWidget {
  final ItemWithRelations item;
  final VoidCallback onTap;

  const _ItemResultTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kiri: Ikon kategori berukuran kecil
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: Icon(
                  CategoryIcons.getIcon(item.categoryIconKey),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Tengah: Nama barang (tebal) & nama kategori di bawahnya (kecil, abu-abu)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.categoryName,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Kanan: Harga eceran besar + satuan kecil, lalu harga grosir lebih kecil
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        AppFormatters.formatRupiah(item.retailPrice),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${item.retailUnitName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.wholesalePrice != null && item.wholesaleUnitName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Grosir: ${AppFormatters.formatRupiah(item.wholesalePrice!)} / ${item.wholesaleUnitName}',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}