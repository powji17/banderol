import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/app_database.dart';
import '../items/items_provider.dart';
import 'csv_service.dart';

class SettingsBackupScreen extends ConsumerStatefulWidget {
  const SettingsBackupScreen({super.key});

  @override
  ConsumerState<SettingsBackupScreen> createState() => _SettingsBackupScreenState();
}

class _SettingsBackupScreenState extends ConsumerState<SettingsBackupScreen> {
  static const _lastBackupKey = 'last_backup_iso';
  DateTime? _lastBackupDate;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastBackupKey);
    if (iso != null && mounted) {
      setState(() => _lastBackupDate = DateTime.tryParse(iso));
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isBusy = true);
    try {
      final items = ref.read(catalogProvider).allItems;
      final csvString = CsvService.encodeItemsToCsv(items);
      final now = DateTime.now();
      final fileName = CsvService.buildFileName(now);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(utf8.encode(csvString));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Backup Katalog Banderol ($fileName)',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, now.toIso8601String());
      if (mounted) {
        setState(() => _lastBackupDate = now);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importCsv() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null || picked.path == null) return;

    setState(() => _isBusy = true);
    try {
      final csvFile = File(picked.path!);
      final content = await csvFile.readAsString(encoding: utf8);
      final rows = CsvService.decodeCsvToRows(content);

      final db = AppDatabase.instance;
      var categories = await db.getAllCategories();
      var units = await db.getAllUnits();

      int importedCount = 0;
      for (final row in rows) {
        // Pastikan kategori tersedia
        var cat = categories
            .where((c) => c.name.toLowerCase() == row.categoryName.toLowerCase())
            .firstOrNull;
        if (cat == null) {
          final newCatId = await db.insertCategory(
            name: row.categoryName,
            iconKey: row.categoryIconKey,
          );
          categories = await db.getAllCategories();
          cat = categories.firstWhere((c) => c.id == newCatId);
        }

        // Pastikan satuan eceran tersedia
        var retailUnit = units
            .where((u) => u.name.toLowerCase() == row.retailUnitName.toLowerCase())
            .firstOrNull;
        if (retailUnit == null) {
          final newUnitId = await db.insertUnit(row.retailUnitName);
          units = await db.getAllUnits();
          retailUnit = units.firstWhere((u) => u.id == newUnitId);
        }

        // Pastikan satuan grosir tersedia jika ada
        int? wholesaleUnitId;
        if (row.wholesalePrice != null && row.wholesaleUnitName != null) {
          var wUnit = units
              .where((u) => u.name.toLowerCase() == row.wholesaleUnitName!.toLowerCase())
              .firstOrNull;
          if (wUnit == null) {
            final newWUnitId = await db.insertUnit(row.wholesaleUnitName!);
            units = await db.getAllUnits();
            wUnit = units.firstWhere((u) => u.id == newWUnitId);
          }
          wholesaleUnitId = wUnit.id;
        }

        // Jika barcode sudah ada, perbarui; jika belum, tambahkan
        final existingByBarcode =
            row.barcode != null ? await db.findItemByBarcode(row.barcode!) : null;

        if (existingByBarcode != null) {
          await db.updateItem(
            id: existingByBarcode.id,
            name: row.name,
            categoryId: cat.id,
            barcode: row.barcode,
            retailPrice: row.retailPrice,
            retailUnitId: retailUnit.id,
            wholesalePrice: row.wholesalePrice,
            wholesaleUnitId: wholesaleUnitId,
          );
        } else {
          await db.insertItem(
            name: row.name,
            categoryId: cat.id,
            barcode: row.barcode,
            retailPrice: row.retailPrice,
            retailUnitId: retailUnit.id,
            wholesalePrice: row.wholesalePrice,
            wholesaleUnitId: wholesaleUnitId,
          );
        }
        importedCount++;
      }

      await ref.read(catalogProvider.notifier).refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor $importedCount barang dari CSV')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengimpor CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _generateDemoData(int count) async {
    setState(() => _isBusy = true);
    try {
      await AppDatabase.instance.generateSampleItems(count);
      await ref.read(catalogProvider.notifier).refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil membuat $count data barang contoh')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBackupOverdue = _lastBackupDate == null ||
        DateTime.now().difference(_lastBackupDate!).inDays > 30;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // FR-52: Pengingat jika terakhir ekspor > 30 hari lalu
          if (isBackupOverdue)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastBackupDate == null
                            ? 'Anda belum pernah melakukan backup ke CSV. Ekspor data secara berkala agar aman.'
                            : 'Backup terakhir lebih dari 30 hari yang lalu. Segera ekspor ulang ke CSV.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Ekspor ke CSV (Excel)'),
            subtitle: const Text('Format UTF-8 dengan BOM, siap dibuka di Excel'),
            trailing: _isBusy ? const CircularProgressIndicator() : null,
            onTap: _isBusy ? null : _exportCsv,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Impor dari CSV'),
            subtitle: const Text('Pulihkan atau tambahkan daftar barang dari file CSV'),
            onTap: _isBusy ? null : _importCsv,
          ),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            'Alat Uji Performa & Portofolio',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Generate 600 Barang Contoh'),
            subtitle: const Text('Simulasi skala toko sembako (Milestone M2)'),
            onTap: _isBusy ? null : () => _generateDemoData(600),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Generate 5.000 Barang Contoh'),
            subtitle: const Text('Uji kecepatan pencarian < 100 ms (Bab 4 & 16 PRD)'),
            onTap: _isBusy ? null : () => _generateDemoData(5000),
          ),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Banderol',
            applicationVersion: '1.0.0 (Offline-First)',
            aboutBoxChildren: [
              Text('Aplikasi Katalog Harga Toko Sembako · Pemilik Produk: Muhammad Fauzi'),
            ],
          ),
        ],
      ),
    );
  }
}