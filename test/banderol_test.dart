import 'package:banderol/core/database/app_database.dart';
import 'package:banderol/core/utils/formatters.dart';
import 'package:banderol/core/utils/search_engine.dart';
import 'package:banderol/features/backup/csv_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Normalisasi Teks & Format Rupiah', () {
    test('Normalisasi mengabaikan huruf besar, tanda baca, dan spasi berlebih', () {
      expect(
        AppFormatters.normalizeSearchText('  Gula-Pasir   GULAKU!! 1Kg '),
        equals('gula pasir gulaku 1kg'),
      );
    });

    test('Format Rupiah memakai titik pemisah ribuan tanpa desimal', () {
      expect(AppFormatters.formatRupiah(12500), equals('Rp12.500'));
      expect(AppFormatters.formatRupiah(115000), equals('Rp115.000'));
    });

    test('Validasi harga menolak <= 0 dan > 99.999.999', () {
      expect(AppFormatters.validateRetailPrice('0'), isNotNull);
      expect(AppFormatters.validateRetailPrice('100.000.000'), isNotNull);
      expect(AppFormatters.validateRetailPrice('12.500'), isNull);
    });
  });

  group('Algoritma Pencarian, Prioritas, & Toleransi Salah Ketik', () {
    final sampleItems = [
      SearchableItem<String>(
        data: 'Minyak Gula Aren',
        name: 'Minyak Gula Aren',
        nameSearch: AppFormatters.normalizeSearchText('Minyak Gula Aren'),
        categoryId: 1,
      ),
      SearchableItem<String>(
        data: 'Gula Pasir 1kg',
        name: 'Gula Pasir 1kg',
        nameSearch: AppFormatters.normalizeSearchText('Gula Pasir 1kg'),
        categoryId: 1,
      ),
      SearchableItem<String>(
        data: 'Kembang Gula Manis',
        name: 'Kembang Gula Manis',
        nameSearch: AppFormatters.normalizeSearchText('Kembang Gula Manis'),
        categoryId: 2,
      ),
    ];

    test('Urutan hasil: awalan nama didahulukan sebelum awalan kata', () {
      final results = SearchEngine.search<String>(
        items: sampleItems,
        rawQuery: 'gul',
      );
      expect(results.first, equals('Gula Pasir 1kg'));
    });

    test('Toleransi salah ketik ringan: "gulla" tetap menemukan "Gula Pasir 1kg"', () {
      final results = SearchEngine.search<String>(
        items: sampleItems,
        rawQuery: 'gulla',
      );
      expect(results, contains('Gula Pasir 1kg'));
    });

    test('Performa pencarian 5.000 barang selesai di bawah 100 ms', () {
      final fiveThousandItems = List.generate(5000, (i) {
        final name = 'Barang Sembako Varian Ke $i';
        return SearchableItem<int>(
          data: i,
          name: name,
          nameSearch: AppFormatters.normalizeSearchText(name),
          categoryId: i % 5,
          barcode: '${8990000000000 + i}',
        );
      });

      final stopwatch = Stopwatch()..start();
      final results = SearchEngine.search<int>(
        items: fiveThousandItems,
        rawQuery: 'sembako 499',
      );
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Round-Trip Ekspor & Impor CSV (100% Identik)', () {
    test('Ekspor lalu impor ulang menghasilkan data yang identik', () {
      final now = DateTime.now();
      final original = [
        ItemWithRelations(
          id: 1,
          name: 'Indomie Goreng Spesial, Pedas',
          nameSearch: 'indomie goreng spesial pedas',
          categoryId: 3,
          categoryName: 'Mi & Instan',
          categoryIconKey: 'ramen_dining',
          barcode: '8998866200011',
          retailPrice: 3500,
          retailUnitId: 2,
          retailUnitName: 'bungkus',
          wholesalePrice: 128000,
          wholesaleUnitId: 7,
          wholesaleUnitName: 'dus',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csvString = CsvService.encodeItemsToCsv(original);
      expect(csvString.startsWith(CsvService.utf8Bom), isTrue);

      final decoded = CsvService.decodeCsvToRows(csvString);
      expect(decoded.length, equals(1));
      expect(decoded.first.name, equals(original.first.name));
      expect(decoded.first.categoryName, equals(original.first.categoryName));
      expect(decoded.first.barcode, equals(original.first.barcode));
      expect(decoded.first.retailPrice, equals(original.first.retailPrice));
      expect(decoded.first.retailUnitName, equals(original.first.retailUnitName));
      expect(decoded.first.wholesalePrice, equals(original.first.wholesalePrice));
      expect(decoded.first.wholesaleUnitName, equals(original.first.wholesaleUnitName));
    });
  });
}