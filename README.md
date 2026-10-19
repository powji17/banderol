# Banderol

**Katalog harga toko sembako yang jalan offline di HP Android. Cari harga barang dalam hitungan detik, tanpa perlu menghafal.**

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![Offline](https://img.shields.io/badge/Mode-Offline-informational)

<!-- TODO: tambahkan GIF demo singkat (30-60 detik) di sini, mis. docs/demo.gif -->

## Tentang Proyek

Banderol (kata lain untuk label harga) lahir dari masalah nyata: saat menjaga toko sembako milik keluarga, saya sering lupa harga barang. Toko menjual ratusan jenis barang, dan hampir setiap barang punya dua harga: **eceran** dan **grosir/kartonan**. Pembeli menunggu, jadi harga harus ketemu cepat.

Banderol bekerja seperti buku kontak untuk harga barang: ketik beberapa huruf atau scan barcode kemasan, dan harganya langsung tampil besar dan jelas.

## Fitur

- **Pencarian cepat** berdasarkan nama barang, hasil muncul langsung saat mengetik.
- **Scan barcode** lewat kamera untuk menemukan barang atau menambahkan barang baru.
- **Dua harga per barang**: harga eceran dan harga grosir, masing-masing dengan satuannya (pcs, dus, kg, karung, dan lainnya).
- **Kategori dan satuan** yang bisa dikelola sendiri.
- **Penelusuran per kategori** untuk menyaring daftar barang.
- **Tambah dan ubah barang** lewat form, serta halaman detail barang.
- **Backup lewat CSV**: ekspor seluruh data ke file CSV dan impor kembali. Saat impor, barang dengan barcode yang sama diperbarui, sedangkan barang lainnya ditambahkan.
- **Sepenuhnya offline**: data tersimpan di database SQLite di perangkat, tanpa akun dan tanpa server.

## Tampilan

<!-- TODO: ganti dengan screenshot asli, simpan di docs/screenshots/ -->

| Pencarian | Detail Barang | Form Barang | Backup |
|---|---|---|---|
| ![Pencarian](docs/screenshots/home.png) | ![Detail](docs/screenshots/detail.png) | ![Form](docs/screenshots/form.png) | ![Backup](docs/screenshots/backup.png) |

## Teknologi

| Aspek | Pilihan |
|---|---|
| Framework | Flutter (Dart) |
| Database lokal | SQLite lewat [Drift](https://pub.dev/packages/drift) |
| State management | [Riverpod](https://pub.dev/packages/flutter_riverpod) |
| Scan barcode | [mobile_scanner](https://pub.dev/packages/mobile_scanner) |
| Backup | CSV, [file_picker](https://pub.dev/packages/file_picker), [share_plus](https://pub.dev/packages/share_plus) |

## Struktur Proyek

```
lib/
├── main.dart
├── core/
│   ├── theme/            # tema aplikasi
│   ├── utils/            # pemformat harga (Rupiah) dan mesin pencarian
│   └── database/         # skema dan akses database (Drift)
└── features/
    ├── items/            # beranda/pencarian, detail, form barang, scanner barcode
    ├── categories/       # pengelolaan kategori
    ├── units/            # pengelolaan satuan
    └── backup/           # ekspor/impor CSV dan halaman pengaturan
test/
└── banderol_test.dart
```

## Keputusan Desain

- **Offline-first.** Toko tidak selalu punya sinyal stabil, dan data harga tidak perlu keluar dari HP. Semua fitur berjalan tanpa internet.
- **Cakupan sengaja kecil.** Versi pertama hanya mencatat harga. Stok, kasir, dan sinkronisasi ditunda agar aplikasi tetap cepat dan sederhana.
- **Backup lewat file biasa.** CSV dipilih karena bisa dibuka dan diedit di Excel, dan tidak butuh layanan cloud.
- **Pencarian ditulis sendiri** (`lib/core/utils/search_engine.dart`) agar perilaku dan kecepatannya bisa dikendalikan penuh.

## Cara Menjalankan

### Prasyarat

- [Flutter SDK](https://docs.flutter.dev/install) (channel stable)
- Android Studio dengan Android SDK, Platform-Tools, Build-Tools, dan Command-line Tools
- Emulator Android, atau HP Android dengan USB debugging aktif

Cek kesiapan lingkungan:

```bash
flutter doctor
```

### Langkah

```bash
# 1. Unduh dependensi
flutter pub get

# 2. Generate kode Drift (jika berkas *.g.dart belum ada)
dart run build_runner build --delete-conflicting-outputs

# 3. Jalankan di emulator atau HP yang terhubung
flutter run
```

Build pertama bisa memakan beberapa menit karena Gradle mengunduh komponen yang dibutuhkan.

### Catatan untuk Windows

Jika proyek berada di drive yang berbeda dari cache pub (mis. proyek di `D:` dan cache di `C:`), kompilasi Kotlin inkremental bisa gagal dengan pesan `this and base files have different roots`. Proyek ini mengatasinya dengan baris berikut di `android/gradle.properties`:

```
kotlin.incremental=false
```

## Pengujian

```bash
flutter analyze
flutter test
```

## Rencana Pengembangan

- [ ] Riwayat perubahan harga
- [ ] Foto barang
- [ ] Isi per kartonan dan harga modal
- [ ] Pencatatan stok dan penanda stok menipis
- [ ] Kalkulator belanja cepat
- [ ] Ekspor daftar harga ke PDF untuk dibagikan lewat WhatsApp
- [ ] Sinkronisasi cloud dan multi-pengguna

## Konvensi Commit

Pesan commit memakai format [Conventional Commits](https://www.conventionalcommits.org/) dalam Bahasa Indonesia, misalnya:

```
feat: tambah impor CSV dengan pembaruan berdasarkan barcode
fix: nonaktifkan kompilasi inkremental Kotlin agar build lolos di Windows
refactor: ganti Share.shareXFiles dengan SharePlus.instance.share
```

## Dokumentasi

<!-- TODO: simpan PRD di docs/PRD.md lalu aktifkan tautan di bawah -->
- Dokumen kebutuhan produk (PRD): `docs/PRD.md`

## Lisensi

<!-- TODO: pilih lisensi (mis. MIT), tambahkan berkas LICENSE, lalu perbarui bagian ini -->
Belum ditentukan.

## Penulis

**Muhammad Fauzi**, mahasiswa Teknik Informatika, Universitas Tanjungpura.

<!-- TODO: tambahkan tautan GitHub atau LinkedIn -->