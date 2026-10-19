import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';

class CsvExportRow {
  final String name;
  final String categoryName;
  final String categoryIconKey;
  final String? barcode;
  final int retailPrice;
  final String retailUnitName;
  final int? wholesalePrice;
  final String? wholesaleUnitName;

  const CsvExportRow({
    required this.name,
    required this.categoryName,
    required this.categoryIconKey,
    this.barcode,
    required this.retailPrice,
    required this.retailUnitName,
    this.wholesalePrice,
    this.wholesaleUnitName,
  });
}

class CsvService {
  static const String utf8Bom = '\uFEFF';

  static const List<String> headers = [
    'name',
    'category_name',
    'category_icon_key',
    'barcode',
    'retail_price',
    'retail_unit',
    'wholesale_price',
    'wholesale_unit',
  ];

  /// Nama file sesuai FR-51: banderol-YYYY-MM-DD.csv
  static String buildFileName(DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return 'banderol-$formatted.csv';
  }

  /// Mengonversi daftar barang menjadi string CSV dengan UTF-8 BOM (FR-50)
  static String encodeItemsToCsv(List<ItemWithRelations> items) {
    final rows = <List<dynamic>>[
      headers,
      ...items.map((item) => [
            item.name,
            item.categoryName,
            item.categoryIconKey,
            item.barcode ?? '',
            item.retailPrice,
            item.retailUnitName,
            item.wholesalePrice ?? '',
            item.wholesaleUnitName ?? '',
          ]),
    ];

    final csvBody = const ListToCsvConverter().convert(rows);
    return '$utf8Bom$csvBody';
  }

  /// Membaca string CSV (mengabaikan UTF-8 BOM jika ada) menjadi daftar baris siap impor
  static List<CsvExportRow> decodeCsvToRows(String csvContent) {
    final cleaned = csvContent.startsWith(utf8Bom)
        ? csvContent.substring(utf8Bom.length)
        : csvContent;

    final rawRows = const CsvToListConverter(shouldParseNumbers: false).convert(cleaned);
    if (rawRows.length <= 1) return [];

    final result = <CsvExportRow>[];
    for (int i = 1; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.length < 6) continue;

      final name = row[0].toString().trim();
      if (name.isEmpty) continue;

      final categoryName = row[1].toString().trim().isEmpty
          ? 'Lainnya'
          : row[1].toString().trim();
      final categoryIconKey = row[2].toString().trim().isEmpty
          ? 'category'
          : row[2].toString().trim();
      final barcode = row[3].toString().trim().isEmpty ? null : row[3].toString().trim();
      final retailPrice = int.tryParse(row[4].toString().trim()) ?? 0;
      final retailUnit = row[5].toString().trim().isEmpty
          ? 'pcs'
          : row[5].toString().trim();

      final wholesalePriceStr = row.length > 6 ? row[6].toString().trim() : '';
      final wholesalePrice =
          wholesalePriceStr.isEmpty ? null : int.tryParse(wholesalePriceStr);
      final wholesaleUnitStr = row.length > 7 ? row[7].toString().trim() : '';
      final wholesaleUnit = wholesaleUnitStr.isEmpty ? null : wholesaleUnitStr;

      if (retailPrice > 0) {
        result.add(
          CsvExportRow(
            name: name,
            categoryName: categoryName,
            categoryIconKey: categoryIconKey,
            barcode: barcode,
            retailPrice: retailPrice,
            retailUnitName: retailUnit,
            wholesalePrice: wholesalePrice,
            wholesaleUnitName: wholesaleUnit,
          ),
        );
      }
    }
    return result;
  }
}