# CampRent POS ⛺🌲
> **Sistem Point of Sale (POS) & Manajemen Rental Alat Camping / Outdoor**  
> Dirancang khusus untuk toko persewaan outdoor dengan arsitektur **Offline-First**, **Manajemen Shift Kasir**, **Katalog Fleksibel (Varian Ukuran)**, dan **Audit Rekonsiliasi Keuangan**.

---

## 📋 Daftar Isi
1. [Tentang CampRent POS](#-tentang-camprent-pos)
2. [Fitur Unggulan Sistem](#-fitur-unggulan-sistem)
   - [A. Kasir & Transaksi Sewa (POS)](#a-kasir--transaksi-sewa-pos)
   - [B. Manajemen Jaminan & Deposit](#b-manajemen-jaminan--deposit)
   - [C. Pengembalian, Inspeksi Fisik & Denda](#c-pengembalian-inspeksi-fisik--denda)
   - [D. Manajemen Shift Kasir & Rekonsiliasi Kas](#d-manajemen-shift-kasir--rekonsiliasi-kas)
   - [E. Laporan Keuangan & Analisis Piutang (Owner)](#e-laporan-keuangan--analisis-piutang-owner)
   - [F. Pengaturan Toko, Akun & Printer Thermal](#f-pengaturan-toko-akun--printer-thermal)
   - [G. Arsitektur Role & Hak Akses (Owner vs Kasir)](#g-arsitektur-role--hak-akses-owner-vs-kasir)
3. [Alur Pemakaian Operasional (User Workflow)](#-alur-pemakaian-operasional-user-workflow)
   - [1. Alur Awal Shift Kasir](#1-alur-awal-shift-kasir)
   - [2. Alur Transaksi Sewa Baru (Check-Out)](#2-alur-transaksi-sewa-baru-check-out)
   - [3. Alur Pengembalian Barang & Pelunasan (Check-In)](#3-alur-pengembalian-barang--pelunasan-check-in)
   - [4. Alur Tutup Shift Kasir](#4-alur-tutup-shift-kasir)
   - [5. Alur Owner Monitoring](#5-alur-owner-monitoring)
4. [Teknologi yang Digunakan](#-teknologi-yang-digunakan)
5. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
6. [Langkah Deployment & Persiapan Siap Pakai](#-langkah-deployment--persiapan-siap-pakai)
   - [A. Menjalankan di Lingkungan Pengembangan](#a-menjalankan-di-lingkungan-pengembangan)
   - [B. Build Android APK & App Bundle (Production)](#b-build-android-apk--app-bundle-production)
   - [C. Build & Deploy Web Production](#c-build--deploy-web-production)
   - [D. Checklist Migrasi ke Database & Cloud Real (Supabase)](#d-checklist-migrasi-ke-database--cloud-real-supabase)
   - [E. Konfigurasi Printer Thermal Fisik](#e-konfigurasi-printer-thermal-fisik)
7. [Pengujian Otomatis (Testing)](#-pengujian-otomatis-testing)

---

## 🌟 Tentang CampRent POS

**CampRent POS** adalah aplikasi kasir dan manajemen operasional persewaan peralatan outdoor (tenda, carrier, sleeping bag, sepatu gunung, kompor camping, dll.). Aplikasi ini memecahkan tantangan unik rental outdoor:
- **Perhitungan durasi sewa fleksibel** (berdasarkan tanggal, bukan sekadar jam retail).
- **Pengawasan jaminan fisik (KTP/SIM/KTM/Paspor)** dan **deposit uang tunai**.
- **Inspeksi kondisi barang saat pengembalian** (bersih, kotor, rusak, hilang) dengan denda otomatis.
- **Katalog produk sederhana tanpa varian warna/foto berat**, mengutamakan **varian ukuran** (misal: sepatu ukuran 39, 40, 41 atau tenda kapasitas 2P, 4P).
- **Offline-First Resilience**: Tetap dapat memproses transaksi sewa di lokasi gunung/alam bebas dengan koneksi internet minim atau terputus.

---

## 🚀 Fitur Unggulan Sistem

### A. Kasir & Transaksi Sewa (POS)
- **Tampilan Grid 2 Kolom Responsif**: Tampilan katalog produk di perangkat ponsel otomatis tersusun rapi dalam 2 kolom (kiri & kanan) seperti aplikasi kasir modern.
- **Filter Kategori Cepat**: Tab kategori geser horizontal untuk memfilter jenis alat outdoor.
- **Pencarian Cepat**: Pencarian real-time berdasarkan nama produk, kategori, atau ukuran.
- **Dukungan Varian Ukuran**: Produk dengan ukuran (sepatu/sandal) memiliki modal pemilihan ukuran instan dengan stok per ukuran.
- **Floating Cart Indicator**: Ringkasan keranjang sewa mengapung di bagian bawah layar menampilkan jumlah alat, durasi sewa, dan subtotal sewa.
- **Kalkulator Pembayaran & Kembalian Tunai**: 
  - Input nominal uang tunai yang diterima dari pelanggan.
  - Quick chip nominal uang pas (`Uang Pas`, `+Rp 50.000`, `+Rp 100.000`, dll.).
  - Validasi otomatis: tombol terkunci jika uang tunai kurang dari tagihan.

### B. Manajemen Jaminan & Deposit
- **Jaminan Fisik**: Pilihan dokumen jaminan wajib (KTP, SIM A/C, KTM, Kartu Pelajar, Paspor) lengkap dengan nomor identitas dan foto/catatan kondisi dokumen.
- **Deposit Uang Tunai**: Alternatif jaminan uang deposit yang disimpan sementara di laci kasir dan otomatis dikembalikan/dipotong saat pengembalian barang.
- **Pengawasan Toko**: Dasbor ringkasan jumlah dokumen fisik yang sedang dipegang toko dan total dana deposit aktif.

### C. Pengembalian, Inspeksi Fisik & Denda
- **Filter Tab Status Rental**: Semua, Aktif, Selesai, Terlambat, dan Dibatalkan.
- **Badge Peringatan Terlambat**: Menghitung otomatis keterlambatan (hari) berdasarkan tanggal jatuh tempo dan kebijakan toleransi toko.
- **Modal Inspeksi Fisik Komprehensif**:
  - Pemeriksaan unit per unit: kondisi **Baik**, **Kotor** (denda cuci), **Rusak** (biaya reparasi), atau **Hilang** (denda penggantian unit).
  - Penghitungan denda otomatis berdasarkan kebijakan toko atau input kustom kasir.
  - Otomatis memotong uang deposit yang dipegang toko untuk melunasi sisa sewa dan denda.
  - Opsi serah-terima kembali jaminan fisik ke pelanggan secara aman.

### D. Manajemen Shift Kasir & Rekonsiliasi Kas
- **Kasir Wajib Buka Shift**: Kasir harus memasukkan modal awal kas sebelum dapat mengakses alur transaksi.
- **Proteksi Akses Operasional (`ShiftGuard`)**: Mencegah kasir membuat transaksi jika belum memulai shift kerja.
- **Audit Rekonsiliasi Kas Final**:
  - Saat tutup shift, kasir memasukkan uang fisik aktual di laci.
  - Sistem membandingkan kas fisik dengan perhitungan sistem (*Modal Awal + Penerimaan Tunai - Pengeluaran Kas*).
  - Status rekonsiliasi visual: **Kas Sesuai** (hijau), **Kas Lebih** (biru), atau **Kas Kurang** (merah).
  - Input catatan kasir jika terjadi selisih kas.
- **Dashboard Shift untuk Owner**: Owner dapat memantau status seluruh shift kasir, ringkasan penerimaan (Tunai, Transfer, QRIS), dan mencetak bukti ringkasan shift.

### E. Laporan Keuangan & Analisis Piutang (Owner)
- **Ringkasan Keuangan Gratis**:
  - Total omzet masuk.
  - Komposisi metode pembayaran: Tunai, Transfer Bank, dan QRIS.
  - Rincian penerimaan DP, pelunasan sewa, dan penerimaan denda.
- **Analisis Keterlambatan & Piutang (100% Gratis)**:
  - Kartu metrik: Unit transaksi terlambat, total piutang sewa belum lunas, dan deposit ditahan.
  - Filter rentang periode: Semua Periode, Hari Ini, 7 Hari Terakhir, Bulan Ini.
  - Daftar transaksi bermasalah & belum lunas lengkap dengan kontak WhatsApp pelanggan.
- **Pratinjau Fitur Analitik Pro**: Grafik tren omzet 7 hari, jam sibuk transaksi rental, performa produk terlaris, dan ekspor data (PDF/Excel).

### F. Pengaturan Toko, Akun & Printer Thermal
- **Kelola Akun Kasir**: Mengelola daftar akun kasir, status aktif/nonaktif, dan edit profil kasir.
- **Kebijakan & Aturan Rental**:
  - DP minimum sewa (persentase).
  - Besaran denda keterlambatan per hari.
  - Toleransi hari keterlambatan (grace period).
  - Default & minimum nominal deposit uang jaminan.
- **Pratinjau & Cetak Struk Thermal**:
  - Dukungan kertas struk ukuran **58mm** dan **80mm**.
  - Pilihan logo toko kustom (ikon tenda, kompas, gunung, atau upload custom).
  - Baris media sosial toko (Instagram, Facebook, TikTok).
  - Cetak struk sewa awal, struk pelunasan pengembalian, dan salinan struk (*Copy Struk*).
  - Opsi bagikan struk digital dalam format PDF.

### G. Arsitektur Role & Hak Akses (Owner vs Kasir)
| Menu / Fitur | Owner (Admin) | Kasir (Staff) |
|---|:---:|:---:|
| Buka / Tutup Shift | Bebas (Opsional) | **Wajib Buka Shift** |
| Transaksi Sewa (POS) | ✅ Penuh | ✅ Penuh |
| Daftar Transaksi & Cetak Ulang Struk | ✅ Penuh | ✅ Penuh |
| Pengembalian Alat & Pelunasan | ✅ Penuh | ✅ Penuh |
| Inventori & Stok Produk | ✅ Tambah / Edit / Hapus | 👁️ Hanya Lihat Stok |
| Tambah / Edit Kategori Produk | ✅ Penuh | ❌ Tidak Ada Akses |
| Data & Blacklist Pelanggan | ✅ Penuh | ✅ Penuh |
| Laporan Keuangan & Omzet | ✅ Penuh | ❌ Tidak Ada Akses |
| Pengaturan Toko, Denda & Akun Kasir | ✅ Penuh | ❌ Tidak Ada Akses |
| Dashboard Audit Shift Seluruh Kasir | ✅ Penuh | ❌ Hanya Shift Sendiri |

---

## 🔄 Alur Pemakaian Operasional (User Workflow)

### 1. Alur Awal Shift Kasir
```
Kasir Login -> Masukkan Modal Awal Laci -> Tekan "Mulai Shift" -> Masuk Layar Kasir POS
```
1. Kasir membuka aplikasi CampRent POS dan masuk dengan akunnya.
2. Jika belum memiliki shift aktif, layar utama menampilkan **Buka Shift Kasir**.
3. Kasir menghitung modal receh/uang kembalian di laci kasir dan memasukkan nominalnya.
4. Menekan tombol **"Mulai Shift & Buka Kasir"**. Sistem mencatat waktu mulai dan membuka akses transaksi.

### 2. Alur Transaksi Sewa Baru (Check-Out)
```
Pilih Alat -> Pilih Ukuran & Qty -> Buka Keranjang -> Tentukan Tanggal Ambil & Kembali -> 
Pilih Dokumen Jaminan / Deposit -> Pilih Pembayaran (DP / Lunas) -> Hitung Uang Tunai -> Simpan & Cetak Struk
```
1. Kasir memilih alat camping yang disewa dari katalog 2-kolom.
2. Jika produk memiliki ukuran (sepatu/sandal), pilih ukuran yang diminta pelanggan.
3. Buka keranjang sewa (*Bottom Sheet*), tentukan tanggal pengambilan dan tanggal pengembalian (durasi hari otomatis dihitung).
4. Pilih jaminan: **Jaminan Fisik** (KTP/SIM/KTM) atau **Deposit Uang**.
5. Pilih pembayaran: **Uang Muka (DP)** minimal sesuai aturan toko atau **Pelunasan Langsung (100%)**.
6. Pilih metode pembayaran (Tunai, Transfer, QRIS). Jika tunai, masukkan nominal uang yang diterima untuk memverifikasi kembalian.
7. Tekan **"Simpan & Cetak Struk"**. Struk sewa keluar dan alat siap diserahkan ke pelanggan.

### 3. Alur Pengembalian Barang & Pelunasan (Check-In)
```
Buka Menu Transaksi -> Cari Nama / No. Transaksi -> Tekan "Proses Pengembalian" -> 
Inspeksi Kondisi Unit -> Sistem Hitung Denda & Sisa Sewa -> Potong Deposit (Bila Ada) -> 
Pelunasan Tunai / Kembalian -> Kembalikan Jaminan Fisik -> Selesai & Cetak Struk Pelunasan
```
1. Buka menu **Transaksi**, temukan transaksi pelanggan yang mengembalikan alat.
2. Tekan tombol **"Proses Pengembalian"** untuk membuka modal inspeksi fisik.
3. Periksa tiap barang:
   - Jika kotor: pilih *Kotor* (denda cuci otomatis terhitung).
   - Jika rusak/hilang: pilih *Rusak/Hilang* (biaya perbaikan/penggantian unit otomatis terhitung).
4. Jika pelanggan terlambat, denda telat harian otomatis ditambahkan berdasarkan jatuh tempo.
5. Jika ada deposit uang, deposit otomatis digunakan untuk menutup tagihan. Jika ada kelebihan, sistem menghitung uang kembalian deposit untuk pelanggan.
6. Kasir menerima sisa pelunasan (jika ada), menandai pengembalian fisik KTP/SIM pelanggan, lalu menekan **"Selesaikan & Cetak Struk Pelunasan"**.

### 4. Alur Tutup Shift Kasir
```
Menu Kasir -> Tekan "Tutup Shift" -> Hitung Total Uang Tunai Fisik di Laci -> 
Masukkan Kas Aktual -> Tulis Catatan (Jika Selisih) -> Konfirmasi Tutup Shift
```
1. Di akhir jam kerja, kasir menekan tombol **"Tutup Shift"**.
2. Kasir menghitung seluruh uang tunai fisik yang ada di laci (termasuk modal awal + penjualan tunai + pelunasan tunai).
3. Masukkan nominal kas aktual ke dalam form.
4. Sistem secara transparan menampilkan status rekonsiliasi (*Kas Sesuai*, *Kas Lebih*, atau *Kas Kurang*).
5. Kasir mengonfirmasi penutupan shift. Data shift terkunci dan siap diaudit oleh Owner.

### 5. Alur Owner Monitoring
```
Owner Login -> Buka Menu Laporan -> Pantau Omzet Harian -> Cek Analisis Piutang & Terlambat -> 
Buka Menu Shift -> Audit Selisih Kasir -> Ekspor Laporan
```
1. Owner login menggunakan akun Owner (memiliki hak akses seluruh menu).
2. Membuka **Laporan Keuangan** untuk memantau omzet masuk, metode pembayaran, serta daftar pelanggan yang masih memiliki piutang sisa sewa atau keterlambatan unit.
3. Membuka **Manajemen Shift** melalui ikon jam/shift di AppBar untuk mengaudit apakah ada kasir yang memiliki selisih kas fisik.

---

## 🛠️ Teknologi yang Digunakan

| Komponen | Teknologi | Keterangan |
|---|---|---|
| **Framework Utama** | **Flutter 3.x** | Multi-platform UI framework (Android, iOS, Web, Desktop) |
| **Bahasa Pemrograman**| **Dart 3.x** | Strongly typed, null-safe language |
| **State Management** | **Flutter Riverpod** | Reactive, compile-safe state management tanpa context leaks |
| **Arsitektur Aplikasi**| **Feature-Driven / Clean Architecture** | Pemisahan tegas: `core/`, `domain/`, `data/`, dan `presentation/` |
| **Perhitungan Bisnis**| **Pure Dart Calculator Engine** | Mesin kalkulator sewa, denda, dan rekonsiliasi bebas dependensi UI |
| **Offline-First Storage** | **SQLite / Simulated Outbox Queue** | Penyimpanan transaksi lokal andal saat tidak ada koneksi internet |
| **Percetakan Thermal**| **ESC/POS Thermal Engine** | Generator struk thermal 58mm & 80mm dengan pratinjau kanvas |
| **Desain Antarmuka** | **Material Design 3 + Custom Emerald Green** | Palet warna tema outdoor premium, font responsif, bebas *layout overflow* |

---

## 📁 Struktur Direktori Proyek

```
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart            # Palet warna emerald green, typography, styling
│   └── utils/
│       ├── currency_formatter.dart   # Pemformat mata uang Rupiah (Rp xx.xxx)
│       └── date_formatter.dart       # Pemformat tanggal dan jam Indonesia
│
├── domain/
│   └── calculator.dart               # Pure business engine: durasi, DP, denda, selisih kas
│
├── data/
│   └── models/
│       ├── item_model.dart           # Model produk & varian ukuran
│       ├── category_model.dart       # Model kategori produk
│       ├── rental_model.dart         # Model transaksi sewa, jaminan, & deposit
│       ├── customer_model.dart       # Model pelanggan & status blacklist
│       ├── settings_model.dart       # Model pengaturan toko, denda, & media sosial
│       ├── printer_model.dart        # Model konfigurasi printer thermal 58mm/80mm
│       └── shift_model.dart          # Model shift kasir & audit rekonsiliasi
│
└── presentation/
    ├── screens/
    │   ├── main_shell.dart           # Navigasi utama, AppBar, role switcher simulator
    │   ├── login_screen.dart         # Layar login & quick login role
    │   ├── pos_screen.dart           # Layar kasir (grid 2-kolom mobile)
    │   ├── rentals_screen.dart       # Layar daftar transaksi & filter status
    │   ├── inventory_screen.dart     # Layar stok produk (Owner CRUD)
    │   ├── customers_screen.dart     # Layar manajemen pelanggan & blacklist
    │   ├── reports_screen.dart       # Layar laporan keuangan & analisis piutang
    │   ├── settings_screen.dart      # Layar pengaturan toko, akun kasir, & printer
    │   └── shift_management_screen.dart # Layar dashboard audit shift kasir
    │
    ├── state/
    │   └── app_state.dart            # StateNotifier Riverpod & mock local data
    │
    └── widgets/
        ├── cart_bottom_sheet.dart    # Lembar keranjang POS & kalkulator tunai
        ├── return_inspection_dialog.dart # Modal inspeksi fisik & denda barang
        ├── receipt_preview_dialog.dart   # Pratinjau struk thermal & unduh PDF
        ├── open_shift_view.dart      # Form buka shift wajib kasir
        ├── close_shift_dialog.dart   # Modal tutup shift & hitung kas fisik
        ├── item_form_dialog.dart     # Modal tambah / edit produk & varian ukuran
        ├── category_management_dialog.dart # Modal kelola kategori produk
        ├── customer_selector_dialog.dart   # Modal pemilih pelanggan
        ├── printer_test_dialog.dart  # Modal uji coba printer thermal
        ├── shift_guard_dialog.dart   # Peringatan wajib shift aktif
        └── status_pill.dart          # Komponen badge status transaksi & jaminan
```

---

## 📦 Langkah Deployment & Persiapan Siap Pakai

### A. Menjalankan di Lingkungan Pengembangan

1. **Pastikan Flutter SDK terpasang**:
   ```bash
   flutter --version
   ```
2. **Unduh dependensi**:
   ```bash
   flutter pub get
   ```
3. **Jalankan aplikasi di browser Chrome (Web)**:
   ```bash
   flutter run -d chrome --web-port=5000
   ```
4. **Jalankan aplikasi di perangkat Android / Emulator**:
   ```bash
   flutter run -d android
   ```

---

### B. Build Android APK & App Bundle (Production)

Untuk merilis aplikasi ke tablet/HP Android operasional toko atau mengunggah ke Google Play Store:

1. **Uji integritas kode terlebih dahulu**:
   ```bash
   flutter analyze
   flutter test
   ```
2. **Build Standalone APK (Dapat langsung di-install di HP/Tablet kasir)**:
   ```bash
   flutter build apk --release
   ```
   *File keluaran:* `build/app/outputs/flutter-apk/app-release.apk`

3. **Build App Bundle (AAB - Untuk rilis ke Google Play Store)**:
   ```bash
   flutter build appbundle --release
   ```
   *File keluaran:* `build/app/outputs/bundle/release/app-release.aab`

4. **Konfigurasi Keystore / Signing (Sebelum Rilis Final)**:
   - Buat keystore menggunakan `keytool`:
     ```bash
     keytool -genkey -v -keystore camprent-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias camprent
     ```
   - Buat file `android/key.properties` berisi kredensial keystore.
   - Perbarui file `android/app/build.gradle` pada blok `signingConfigs.release`.

---

### C. Build & Deploy Web Production

Aplikasi kasir ini dapat diakses melalui browser komputer toko, tablet, atau laptop kasir:

1. **Build bundle web production**:
   ```bash
   flutter build web --release --pwa-strategy=offline-first
   ```
   *Hasil kompilasi:* Folder `build/web/`

2. **Opsi Hosting Web**:
   - **Firebase Hosting**:
     ```bash
     npm install -g firebase-tools
     firebase login
     firebase init hosting
     firebase deploy
     ```
   - **Vercel**:
     Pasang Vercel CLI atau sambungkan repositori GitHub ke dashboard Vercel dengan *Output Directory* diarahkan ke `build/web`.
   - **Nginx / VPS Tradisional**:
     Salin isi folder `build/web/*` ke root direktori web server (misal `/var/www/camprent-pos`).

---

### D. Checklist Migrasi ke Database & Cloud Real (Supabase)

Saat ini aplikasi telah memiliki arsitektur **Data Layer terpisah** (`data/models/` dan `domain/calculator.dart`). Untuk menyambungkan ke backend Supabase cloud:

1. **Tambah dependensi Supabase di `pubspec.yaml`**:
   ```yaml
   dependencies:
     supabase_flutter: ^2.8.0
   ```
2. **Inisialisasi di `lib/main.dart`**:
   ```dart
   await Supabase.initialize(
     url: 'https://xyzcompany.supabase.co',
     anonKey: 'eyJh......',
   );
   ```
3. **Skema Tabel SQL Supabase yang Diperlukan**:
   - `stores`: Identitas toko, nama, alamat, no. telepon, aturan DP, denda harian.
   - `categories`: Daftar kategori produk (`name`, `requires_size`).
   - `products`: Master produk sewa (`name`, `category_id`, `daily_price`, `replacement_price`, `is_active`).
   - `product_variants`: Stok per varian ukuran (`product_id`, `size`, `total_stock`, `available_stock`).
   - `customers`: Data penyewa (`name`, `phone`, `nik`, `is_blacklisted`).
   - `rentals`: Transaksi sewa (`rental_number`, `customer_id`, `pickup_date`, `return_date`, `status`, `total_fee`, `dp_amount`).
   - `cashier_shifts`: Sesi kerja kasir (`cashier_name`, `initial_cash`, `actual_cash`, `status`, `difference`).

---

### E. Konfigurasi Printer Thermal Fisik

Aplikasi telah dilengkapi logika percetakan **ESC/POS Thermal Engine**:
- **Format Struk**: Mendukung printer kasir thermal ukuran 58mm (kertas kecil/portable bluetooth) dan 80mm (desktop USB/LAN/Bluetooth).
- **Integrasi Bluetooth Perangkat Fisik**:
  - Di Android native, gunakan plugin seperti `print_bluetooth_thermal` atau `esc_pos_bluetooth` untuk menghubungkan *MAC Address* printer kasir yang dipilih di menu **Pengaturan -> Pengaturan Printer Thermal**.

---

## 🧪 Pengujian Otomatis (Testing)

Aplikasi memiliki rangkaian **Unit Tests & Acceptance Criteria Tests** lengkap yang mencakup perhitungan durasi, denda keterlambatan, pemotongan deposit, hak akses role, serta alur rekonsiliasi kas:

Jalankan seluruh pengujian dengan satu perintah:
```bash
flutter test
```

**Status Pengujian Terverifikasi:**
```
00:02 +27: All tests passed! (100% Passed)
```

---

## 📄 Lisensi
Hak Cipta © 2026 CampRent POS. Seluruh hak cipta dilindungi undang-undang.
Dirancang untuk efisiensi bisnis persewaan outdoor & camping.
