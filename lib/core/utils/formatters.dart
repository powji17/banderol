import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppFormatters {
  static const int maxReasonablePrice = 99999999;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _thousandFormat = NumberFormat.decimalPattern('id_ID');

  /// Format integer ke tampilan Rp12.500
  static String formatRupiah(int price) {
    return _currencyFormat.format(price);
  }

  /// Format integer ke angka bertitik 12.500 (untuk field input)
  static String formatThousand(int number) {
    return _thousandFormat.format(number);
  }

  /// Parsing teks input berformat titik menjadi int
  static int? parseRupiahInput(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;
    return int.tryParse(digitsOnly);
  }

  /// Normalisasi nama barang untuk pencarian:
  /// huruf kecil, hapus tanda baca, rapikan spasi berlebih
  static String normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Validasi harga wajib (eceran)
  static String? validateRetailPrice(String? value) {
    final parsed = parseRupiahInput(value ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Harga eceran wajib lebih dari 0';
    }
    if (parsed > maxReasonablePrice) {
      return 'Harga maksimal Rp99.999.999 (cek kelebihan nol)';
    }
    return null;
  }

  /// Validasi harga opsional (grosir)
  static String? validateWholesalePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = parseRupiahInput(value);
    if (parsed == null || parsed <= 0) {
      return 'Harga grosir harus lebih dari 0';
    }
    if (parsed > maxReasonablePrice) {
      return 'Harga maksimal Rp99.999.999 (cek kelebihan nol)';
    }
    return null;
  }
}

/// TextInputFormatter untuk memformat angka ribuan secara otomatis saat diketik
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final number = int.tryParse(digitsOnly);
    if (number == null) return oldValue;

    final formatted = AppFormatters.formatThousand(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}