import 'formatters.dart';

class SearchableItem<T> {
  final T data;
  final String name;
  final String nameSearch;
  final int categoryId;
  final String? barcode;

  const SearchableItem({
    required this.data,
    required this.name,
    required this.nameSearch,
    required this.categoryId,
    this.barcode,
  });
}

class SearchEngine {
  /// Menjalankan pencarian cepat di memori sesuai prioritas FR-13 & FR-16
  static List<T> search<T>({
    required List<SearchableItem<T>> items,
    required String rawQuery,
    int? selectedCategoryId,
  }) {
    // 1. Saring berdasarkan kategori jika dipilih (FR-15)
    final categoryFiltered = selectedCategoryId == null
        ? items
        : items.where((item) => item.categoryId == selectedCategoryId).toList();

    final normalizedQuery = AppFormatters.normalizeSearchText(rawQuery);
    final rawTrimmed = rawQuery.trim();

    // 2. Tanpa kueri pencarian: urut abjad berdasarkan nama (FR-16)
    if (normalizedQuery.isEmpty && rawTrimmed.isEmpty) {
      final sorted = List<SearchableItem<T>>.from(categoryFiltered)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted.map((e) => e.data).toList();
    }

    final bucketStartsWithName = <SearchableItem<T>>[];
    final bucketStartsWithWord = <SearchableItem<T>>[];
    final bucketContains = <SearchableItem<T>>[];
    final bucketTypo = <SearchableItem<T>>[];

    final queryTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();

    for (final item in categoryFiltered) {
      final target = item.nameSearch;
      final words = target.split(' ').where((w) => w.isNotEmpty).toList();

      // Prioritas 1: Awalan nama lengkap
      if (normalizedQuery.isNotEmpty && target.startsWith(normalizedQuery)) {
        bucketStartsWithName.add(item);
        continue;
      }

      // Prioritas 2: Awalan kata (semua token kueri menjadi awalan kata pada nama barang)
      if (queryTokens.isNotEmpty &&
          queryTokens.every((qToken) => words.any((w) => w.startsWith(qToken)))) {
        bucketStartsWithWord.add(item);
        continue;
      }

      // Prioritas 3: Mengandung teks atau cocok dengan angka barcode (FR-13 & FR-17)
      final matchesSubstring = normalizedQuery.isNotEmpty && target.contains(normalizedQuery);
      final matchesBarcode = rawTrimmed.isNotEmpty &&
          item.barcode != null &&
          item.barcode!.toLowerCase().contains(rawTrimmed.toLowerCase());

      if (matchesSubstring || matchesBarcode) {
        bucketContains.add(item);
        continue;
      }

      // Prioritas 4: Toleransi salah ketik menggunakan Jarak Levenshtein
      if (_isTypoMatch(queryTokens, words)) {
        bucketTypo.add(item);
      }
    }

    int compareAlpha(SearchableItem<T> a, SearchableItem<T> b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    bucketStartsWithName.sort(compareAlpha);
    bucketStartsWithWord.sort(compareAlpha);
    bucketContains.sort(compareAlpha);
    bucketTypo.sort(compareAlpha);

    return [
      ...bucketStartsWithName.map((e) => e.data),
      ...bucketStartsWithWord.map((e) => e.data),
      ...bucketContains.map((e) => e.data),
      ...bucketTypo.map((e) => e.data),
    ];
  }

  /// Aturan Levenshtein sesuai Bab 14 PRD:
  /// - Maksimal jarak 1 untuk kata 4 sampai 7 huruf
  /// - Maksimal jarak 2 untuk kata 8 huruf atau lebih
  static bool _isTypoMatch(List<String> queryTokens, List<String> itemWords) {
    if (queryTokens.isEmpty || itemWords.isEmpty) return false;

    for (final q in queryTokens) {
      if (q.length < 4) return false;
      final maxDist = q.length >= 8 ? 2 : 1;

      bool tokenMatched = false;
      for (final word in itemWords) {
        if ((word.length - q.length).abs() <= maxDist) {
          final dist = levenshteinDistance(q, word);
          if (dist <= maxDist) {
            tokenMatched = true;
            break;
          }
        }
      }
      if (!tokenMatched) return false;
    }
    return true;
  }

  /// Menghitung jarak Levenshtein antara dua string s dan t
  static int levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        final deletion = v0[j + 1] + 1;
        final insertion = v1[j] + 1;
        final substitution = v0[j] + cost;
        v1[j + 1] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      final temp = v0;
      v0 = v1;
      v1 = temp;
    }
    return v0[t.length];
  }
}