import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/items/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BanderolApp()));
}

class BanderolApp extends StatelessWidget {
  const BanderolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banderol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // FR-60: Mengikuti pengaturan tema sistem
      home: const HomeScreen(),
    );
  }
}