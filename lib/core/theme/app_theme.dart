import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D7A3E),
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded, // Minimal 48dp
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2ECC71),
        brightness: Brightness.dark,
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
        ),
      ),
    );
  }
}

/// Peta ikon kategori bawaan berbasis Material Icons
class CategoryIcons {
  static const Map<String, IconData> icons = {
    'category': Icons.category,
    'rice_bowl': Icons.rice_bowl,
    'local_drink': Icons.local_drink,
    'ramen_dining': Icons.ramen_dining,
    'cookie': Icons.cookie,
    'cleaning_services': Icons.cleaning_services,
    'Medication': Icons.medication,
    'kitchen': Icons.kitchen,
    'coffee': Icons.coffee,
    'Egg': Icons.egg,
    'smoking_rooms': Icons.smoking_rooms,
    'child_care': Icons.child_care,
    'pets': Icons.pets,
    'inventory_2': Icons.inventory_2,
  };

  static IconData getIcon(String key) {
    return icons[key] ?? Icons.category;
  }
}