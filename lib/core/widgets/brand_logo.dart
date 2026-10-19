import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/items/items_provider.dart';

/// Warna brand Banderol (harus sama dengan res/values/colors.xml)
const Color kBrandGreen = Color(0xFF0B6E4F);
const Color kBrandAmber = Color(0xFFFFB703);

/// Logo tag Banderol.
/// [flat] = versi putih polos tanpa bayangan, dipakai di atas latar berwarna
/// (splash/ikon). Default = versi ber-bayangan, tetap terbaca di latar terang.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28, this.flat = false});

  final double size;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      flat ? 'assets/images/logo_tag_flat.png' : 'assets/images/logo_tag.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Splash in-app: tampil sampai katalog selesai dimuat dari database,
/// jadi pengguna tidak melihat kedipan daftar kosong saat aplikasi dibuka.
class SplashGate extends ConsumerWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(catalogProvider).isLoading) return child;

    return const Scaffold(
      backgroundColor: kBrandGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 128, flat: true),
            SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: kBrandAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
