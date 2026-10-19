import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';
import 'barcode_scanner_screen.dart';
import 'items_provider.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final ItemWithRelations? editItem;
  final ItemWithRelations? duplicateFromItem;
  final String? initialBarcode;

  const ItemFormScreen({
    super.key,
    this.editItem,
    this.duplicateFromItem,
    this.initialBarcode,
  });

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _retailPriceController;
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _barcodeController;
  final FocusNode _nameFocusNode = FocusNode();

  int? _selectedCategoryId;
  int? _selectedRetailUnitId;
  int? _selectedWholesaleUnitId;

  bool get isEditMode => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final source = widget.editItem ?? widget.duplicateFromItem;
    final catalog = ref.read(catalogProvider);

    _nameController = TextEditingController(
      text: widget.editItem != null
          ? widget.editItem!.name
          : (widget.duplicateFromItem != null
              ? '${widget.duplicateFromItem!.name} (Salinan)'
              : ''),
    );
    _retailPriceController = TextEditingController(
      text: source != null ? AppFormatters.formatThousand(source.retailPrice) : '',
    );
    _wholesalePriceController = TextEditingController(
      text: source?.wholesalePrice != null
          ? AppFormatters.formatThousand(source!.wholesalePrice!)
          : '',
    );
    _barcodeController = TextEditingController(
      text: widget.editItem != null
          ? (widget.editItem!.barcode ?? '')
          : (widget.initialBarcode ?? ''),
    );

    _selectedCategoryId = source?.categoryId ??
        catalog.lastUsedCategoryId ??
        (catalog.categories.isNotEmpty ? catalog.categories.first.id : null);

    _selectedRetailUnitId = source?.retailUnitId ??
        catalog.lastUsedRetailUnitId ??
        (catalog.units.isNotEmpty ? catalog.units.first.id : null);

    _selectedWholesaleUnitId = source?.wholesaleUnitId ??
        catalog.lastUsedWholesaleUnitId ??
        (catalog.units.isNotEmpty ? catalog.units.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _retailPriceController.dispose();
    _wholesalePriceController.dispose();
    _barcodeController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanBarcodeIntoField() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned != null && mounted) {
      setState(() {
        _barcodeController.text = scanned;
      });
    }
  }

  Future<void> _saveItem({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final retailPrice = AppFormatters.parseRupiahInput(_retailPriceController.text)!;
    final wholesalePrice = AppFormatters.parseRupiahInput(_wholesalePriceController.text);

    if (_selectedCategoryId == null || _selectedRetailUnitId == null) return;
    if (wholesalePrice != null && _selectedWholesaleUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih satuan untuk harga grosir')),
      );
      return;
    }

    final db = AppDatabase.instance;

    // FR-25: Cek apakah barcode sudah dipakai barang lain
    if (barcode.isNotEmpty) {
      final existingBarcode = await db.findItemByBarcode(barcode);
      if (existingBarcode != null && existingBarcode.id != widget.editItem?.id) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Barcode Sudah Dipakai'),
            content: Text(
              'Barcode "$barcode" sudah terdaftar pada barang "${existingBarcode.name}". Gunakan barcode yang berbeda.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // FR-25 & Bab 11: Peringatan jika nama sama persis (bukan larangan mutlak)
    final existingName = await db.findItemByExactName(
      name,
      excludeId: widget.editItem?.id,
    );
    if (existingName != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nama Barang Sama Persis'),
          content: Text(
            'Barang bernama "$name" sudah ada di katalog (${AppFormatters.formatRupiah(existingName.retailPrice)} / ${existingName.retailUnitName}).\n\nTetap simpan sebagai barang terpisah?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Periksa Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (isEditMode) {
      await db.updateItem(
        id: widget.editItem!.id,
        name: name,
        categoryId: _selectedCategoryId!,
        barcode: barcode,
        retailPrice: retailPrice,
        retailUnitId: _selectedRetailUnitId!,
        wholesalePrice: wholesalePrice,
        wholesaleUnitId: wholesalePrice != null ? _selectedWholesaleUnitId : null,
      );
    } else {
      await db.insertItem(
        name: name,
        categoryId: _selectedCategoryId!,
        barcode: barcode,
        retailPrice: retailPrice,
        retailUnitId: _selectedRetailUnitId!,
        wholesalePrice: wholesalePrice,
        wholesaleUnitId: wholesalePrice != null ? _selectedWholesaleUnitId : null,
      );
    }

    final notifier = ref.read(catalogProvider.notifier);
    notifier.rememberLastUsed(
      categoryId: _selectedCategoryId!,
      retailUnitId: _selectedRetailUnitId!,
      wholesaleUnitId: _selectedWholesaleUnitId,
    );
    await notifier.refreshAll();

    if (!mounted) return;

    if (addAnother) {
      // FR-21: Reset field teks, tapi pertahankan kategori & satuan terakhir
      _nameController.clear();
      _retailPriceController.clear();
      _wholesalePriceController.clear();
      _barcodeController.clear();
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('"$name" disimpan. Silakan isi barang berikutnya.'),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Ubah Barang' : 'Tambah Barang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Nama Barang (Wajib, maks 100 karakter)
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              autofocus: !isEditMode,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Barang *',
                hintText: 'Mis. Gula Pasir Gulaku 1kg',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama barang wajib diisi';
                }
                if (val.trim().length > 100) {
                  return 'Nama maksimal 100 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 2. Kategori (Wajib)
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori *',
                border: OutlineInputBorder(),
              ),
              items: catalog.categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 16),

            // 3. Harga Eceran & Satuan Eceran (Wajib)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _retailPriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Harga Eceran *',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    validator: AppFormatters.validateRetailPrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedRetailUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Satuan *',
                      border: OutlineInputBorder(),
                    ),
                    items: catalog.units
                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRetailUnitId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Harga Grosir & Satuan Grosir (Opsional)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _wholesalePriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Harga Grosir (Opsional)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                    validator: AppFormatters.validateWholesalePrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedWholesaleUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Satuan Grosir',
                      border: OutlineInputBorder(),
                    ),
                    items: catalog.units
                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedWholesaleUnitId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. Barcode (Opsional, ketik atau scan)
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode (Opsional)',
                hintText: 'Ketik atau ketuk ikon scan',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Scan Barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcodeIntoField,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Simpan & Simpan + Tambah Lagi (FR-21)
            FilledButton.icon(
              onPressed: () => _saveItem(addAnother: false),
              icon: const Icon(Icons.check),
              label: const Text('Simpan'),
            ),
            if (!isEditMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _saveItem(addAnother: true),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Simpan & Tambah Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}