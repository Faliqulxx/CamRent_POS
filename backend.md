# Panduan Integrasi Backend Multi-Tenant & Distribusi APK Gratis
## CampRent POS — Supabase Backend & Direct APK Distribution Guide

Dokumen ini adalah panduan lengkap untuk mengubah **CampRent POS** dari frontend lokal menjadi sistem berbasis cloud yang dapat digunakan oleh **banyak pemilik toko persewaan outdoor (Multi-Tenant SaaS)** secara **100% GRATIS**, serta cara merilis dan mendistribusikan APK langsung ke pemilik toko tanpa biaya pendaftaran Google Play Store ($25).

---

## 📋 Daftar Isi
1. [Arsitektur Multi-Tenant (Banyak Toko)](#1-arsitektur-multi-tenant-banyak-toko)
2. [Langkah 1: Setup Proyek Supabase Gratis (BaaS)](#langkah-1-setup-proyek-supabase-gratis-baas)
3. [Langkah 2: Skrip Database PostgreSQL & RLS (Copy-Paste Ready)](#langkah-2-skrip-database-postgresql--rls-copy-paste-ready)
4. [Langkah 3: Integrasi Supabase ke Aplikasi Flutter](#langkah-3-integrasi-supabase-ke-aplikasi-flutter)
5. [Langkah 4: Strategi Offline-First & Sinkronisasi](#langkah-4-strategi-offline-first--sinkronisasi)
6. [Langkah 5: Build APK Produksi (Release)](#langkah-5-build-apk-produksi-release)
7. [Langkah 6: Distribusi APK 100% Gratis Tanpa Play Store](#langkah-6-distribusi-apk-100-gratis-tanpa-play-store)
8. [Panduan Instalasi untuk Pemilik Toko (Klien)](#panduan-instalasi-untuk-pemilik-toko-klien)

---

## 1. Arsitektur Multi-Tenant (Banyak Toko)

Untuk memungkinkan aplikasi digunakan oleh banyak toko camping yang berbeda tanpa data tertukar:

```
                      [ Pengguna Login (Email/Password) ]
                                      │
                                      ▼
                        [ Supabase Auth (auth.users) ]
                                      │
                                      ▼
                     [ Tabel profiles: role & store_id ]
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼                                         ▼
   [ Toko A (store_id: 111) ]                [ Toko B (store_id: 222) ]
   • Katalog alat Toko A                     • Katalog alat Toko B
   • Transaksi & Piutang Toko A              • Transaksi & Piutang Toko B
   • Kasir & Shift Toko A                    • Kasir & Shift Toko B
   • Pelanggan & Blacklist Toko A            • Pelanggan & Blacklist Toko B
```

Setiap baris data transaksi, inventaris, dan pelanggan diberi identitas `store_id`. Dengan fitur **Row Level Security (RLS)** PostgreSQL, pengguna Toko A **mustahil** melihat data Toko B meskipun mengakses API yang sama.

---

## Langkah 1: Setup Proyek Supabase Gratis (BaaS)

1. Buka [https://supabase.com](https://supabase.com) dan klik **"Start your project"**.
2. Masuk menggunakan akun **GitHub** Anda.
3. Klik **"New Project"**:
   - **Name**: `camprent-pos`
   - **Database Password**: Masukkan password aman (simpan baik-baik).
   - **Region**: Pilih **`Singapore (ap-southeast-1)`** *(sangat penting agar respon aplikasi dari Indonesia sangat cepat, latensi < 30ms)*.
   - **Pricing Plan**: Pilih **Free Plan** ($0 / Rp 0).
4. Klik **"Create new project"** dan tunggu sekitar 1-2 menit hingga provisioning database selesai.
5. Ambil kunci API Anda:
   - Buka menu **Project Settings** (ikon gerigi di kiri bawah) -> **API**.
   - Salin **Project URL** (contoh: `https://xyzproject.supabase.co`).
   - Salin **Project API Keys** bagian **`anon` / `public`**.

---

## Langkah 2: Skrip Database PostgreSQL & RLS (Copy-Paste Ready)

Buka menu **SQL Editor** di dashboard Supabase Anda, buat kueri baru (**"New query"**), lalu salin seluruh skrip SQL berikut dan klik **"Run"**:

```sql
-- ============================================================================
-- 1. EXTENSIONS & ENUM TYPES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE app_role AS ENUM ('owner', 'cashier');
CREATE TYPE rental_status_enum AS ENUM ('active', 'completed', 'overdue', 'cancelled');
CREATE TYPE payment_status_enum AS ENUM ('dp', 'paid', 'unpaid');
CREATE TYPE payment_method_enum AS ENUM ('cash', 'transfer', 'qris');
CREATE TYPE shift_status_enum AS ENUM ('open', 'closed');

-- ============================================================================
-- 2. TABEL PROFIL TOKO (STORES)
-- ============================================================================
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    min_dp_percent INT NOT NULL DEFAULT 30,
    late_fee_per_day NUMERIC NOT NULL DEFAULT 25000,
    late_grace_period_days INT NOT NULL DEFAULT 0,
    default_deposit_amount NUMERIC NOT NULL DEFAULT 50000,
    min_deposit_amount NUMERIC NOT NULL DEFAULT 0,
    receipt_footer_note TEXT DEFAULT 'Terima kasih atas kunjungan Anda. Harap kembalikan alat tepat waktu & bersih.',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. TABEL PROFIL PENGGUNA (PROFILES)
-- ============================================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    role app_role NOT NULL DEFAULT 'cashier',
    name TEXT NOT NULL,
    email TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 4. TABEL KATEGORI PRODUK (CATEGORIES)
-- ============================================================================
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon_name TEXT DEFAULT 'category',
    requires_size BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 5. TABEL PRODUK & ALAT CAMPING (ITEMS)
-- ============================================================================
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    daily_price NUMERIC NOT NULL,
    total_stock INT NOT NULL DEFAULT 0,
    available_stock INT NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Unit',
    has_size_variants BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Varian Ukuran Alat (Sepatu, Tenda, dll.)
CREATE TABLE item_size_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    size TEXT NOT NULL,
    total_stock INT NOT NULL DEFAULT 0,
    available_stock INT NOT NULL DEFAULT 0
);

-- ============================================================================
-- 6. TABEL PELANGGAN (CUSTOMERS)
-- ============================================================================
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    nik TEXT,
    address TEXT,
    is_blacklisted BOOLEAN NOT NULL DEFAULT FALSE,
    blacklist_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 7. TABEL SHIFT KASIR (SHIFTS)
-- ============================================================================
CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    cashier_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    cashier_name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    initial_cash NUMERIC NOT NULL,
    expected_cash NUMERIC,
    actual_cash NUMERIC,
    difference NUMERIC,
    total_sales_cash NUMERIC NOT NULL DEFAULT 0,
    total_sales_transfer NUMERIC NOT NULL DEFAULT 0,
    total_sales_qris NUMERIC NOT NULL DEFAULT 0,
    status shift_status_enum NOT NULL DEFAULT 'open',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 8. TABEL TRANSAKSI RENTAL (RENTALS)
-- ============================================================================
CREATE TABLE rentals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL,
    invoice_number TEXT NOT NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INT NOT NULL,
    subtotal NUMERIC NOT NULL,
    discount NUMERIC NOT NULL DEFAULT 0,
    total_amount NUMERIC NOT NULL,
    paid_amount NUMERIC NOT NULL,
    remaining_balance NUMERIC NOT NULL,
    payment_method payment_method_enum NOT NULL,
    payment_status payment_status_enum NOT NULL,
    rental_status rental_status_enum NOT NULL DEFAULT 'active',
    guarantee_type TEXT,
    guarantee_number TEXT,
    deposit_amount NUMERIC NOT NULL DEFAULT 0,
    late_days INT NOT NULL DEFAULT 0,
    late_fee NUMERIC NOT NULL DEFAULT 0,
    damage_fee NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Item Dalam Rental
CREATE TABLE rental_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    size TEXT,
    qty INT NOT NULL,
    price_per_day NUMERIC NOT NULL,
    subtotal NUMERIC NOT NULL,
    condition_on_return TEXT DEFAULT 'good'
);

-- ============================================================================
-- 9. ROW LEVEL SECURITY (RLS) — KEAMANAN ISOLASI ANTAR TOKO
-- ============================================================================
-- Helper function: Mengambil store_id milik pengguna yang sedang login
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID AS $$
    SELECT store_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Aktifkan RLS di semua tabel
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_size_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rentals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_items ENABLE ROW LEVEL SECURITY;

-- Kebijakan Akses: Hanya bisa baca/tulis data jika store_id sama dengan toko user
CREATE POLICY "store_isolation_stores" ON stores 
    FOR ALL USING (id = get_user_store_id());

CREATE POLICY "store_isolation_profiles" ON profiles 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_categories" ON categories 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_items" ON items 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_size_variants" ON item_size_variants 
    FOR ALL USING (
        item_id IN (SELECT id FROM items WHERE store_id = get_user_store_id())
    );

CREATE POLICY "store_isolation_customers" ON customers 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_shifts" ON shifts 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_rentals" ON rentals 
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "store_isolation_rental_items" ON rental_items 
    FOR ALL USING (
        rental_id IN (SELECT id FROM rentals WHERE store_id = get_user_store_id())
    );
```

---

## Langkah 3: Integrasi Supabase ke Aplikasi Flutter

### 1. Pasang Dependency di `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  supabase_flutter: ^2.8.0 # Tambahkan ini
```
Jalankan di terminal:
```bash
flutter pub get
```

### 2. Inisialisasi Supabase di `lib/main.dart`
Perbarui fungsi `main()` Anda:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camprent_pos/presentation/screens/main_shell.dart';
import 'package:camprent_pos/presentation/screens/login_screen.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase dengan kredensial project Anda
  await Supabase.initialize(
    url: 'https://xyzproject.supabase.co', // Ganti dengan URL project Anda
    anonKey: 'eyJhGciOi...',               // Ganti dengan anon public key Anda
  );

  runApp(
    const ProviderScope(
      child: CampRentApp(),
    ),
  );
}
```

### 3. Buat Service Autentikasi (`lib/data/services/auth_service.dart`)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Login dengan Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Mendapatkan Profil Akun & Data Toko Saat Ini
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('*, stores(*)')
        .eq('id', user.id)
        .single();
    return response;
  }

  // Keluar / Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
```

---

## Langkah 4: Strategi Offline-First & Sinkronisasi

Aplikasi CampRent POS telah memiliki struktur `NetworkStatus` dan `OutboxItem` di state management. Cara kerjanya:

1. **Ketika Ada Internet (Online)**:
   - Setiap transaksi sewa atau pembayaran langsung disimpan ke Supabase via `supabase.from('rentals').insert(...)`.
   - Data lokal diupdate otomatis.
2. **Ketika Internet Mati di Lokasi Camp (Offline)**:
   - Transaksi disimpan ke penyimpanan lokal (SQLite / Hive / SharedPreferences) dengan status `pending_sync`.
   - Indikator topbar otomatis menampilkan status **Offline (N transaksi tersimpan)**.
3. **Ketika Internet Terhubung Kembali (Auto-Sync)**:
   - Listener koneksi mendeteksi status online.
   - Sistem mengirimkan data *outbox* ke Supabase secara berurutan dan mengupdate status menjadi tersinkron.

---

## Langkah 5: Build APK Produksi (Release)

Untuk menghasilkan file APK Android yang optimal dan siap dibagikan ke pemilik toko:

### 1. Build Single APK Universal:
```bash
flutter build apk --release
```
*Hasil file:* `build/app/outputs/flutter-apk/app-release.apk`  
*(Bisa diinstal di semua jenis smartphone Android)*.

### 2. Build APK Ramping (Split per CPU Architecture):
Jika Anda ingin ukuran file unduhan lebih kecil (sekitar 15-20 MB):
```bash
flutter build apk --split-per-abi --release
```
*Hasil file:*
- `app-arm64-v8a-release.apk` (Cocok untuk 95% HP Android modern saat ini).
- `app-armeabi-v7a-release.apk` (Untuk HP Android tipe lama).

---

## Langkah 6: Distribusi APK 100% Gratis Tanpa Play Store

Anda **tidak perlu** membayar $25 untuk akun Google Play Developer. Gunakan cara-cara gratis berikut untuk mendistribusikan APK ke pemilik toko:

### Opsi 1: GitHub Releases (Sangat Direkomendasikan ⭐)
GitHub menyediakan hosting rilis tanpa batas dan tautan unduhan langsung gratis:

1. Buat tag rilis di repositori git lokal:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Buka repositori Anda di browser: `https://github.com/Faliqulxx/CamRent_POS/releases`.
3. Klik **"Draft a new release"**:
   - Pilih tag `v1.0.0`.
   - Isi judul: `CampRent POS v1.0.0 - Rilis Perdana`.
   - Drag & drop file `app-release.apk` ke kotak upload.
4. Klik **"Publish release"**.
5. Anda akan mendapatkan direct download link permanen seperti:
   `https://github.com/Faliqulxx/CamRent_POS/releases/download/v1.0.0/app-release.apk`

---

### Opsi 2: Landing Page Web Gratis (Vercel / GitHub Pages)
Buat satu halaman web sederhana dengan tombol unduh besar dan kode QR:

1. Pemilik toko membuka halaman web (misal: `camprent.vercel.app`).
2. Terdapat tombol: **"Download APK Kasir (Android)"**.
3. Di sampingnya terdapat **QR Code**: Pemilik toko tinggal scan kamera HP dan file APK langsung terunduh ke HP mereka.

---

### Opsi 3: Google Drive / Direct Cloud Link
1. Upload `app-release.apk` ke Google Drive toko Anda.
2. Ubah akses menjadi *"Siapa saja yang memiliki link dapat melihat"*.
3. Ubah link berbagi menjadi direct download atau perpendek menggunakan `bit.ly/camprent-apk`.

---

## Panduan Instalasi untuk Pemilik Toko (Klien)

Sertakan instruksi singkat berikut saat mengirimkan APK kepada pemilik toko/kasir:

1. **Unduh file APK**: Klik link unduhan di smartphone atau tablet Android Anda.
2. **Izinkan Instalasi dari Sumber Tak Dikenal**:
   - Jika muncul peringatan *"Jenis file ini dapat membahayakan perangkat Anda"* atau *"Instal aplikasi yang tidak dikenal"*, klik **Tetap Unduh** / **Buka Pengaturan**.
   - Aktifkan toggle **"Izinkan dari sumber ini"** (Chrome / File Manager).
3. **Instal Aplikasi**: Klik file `app-release.apk` yang telah diunduh, lalu tekan **"Instal"**.
4. **Buka CampRent POS**: Masuk menggunakan akun Owner yang telah Anda buatkan di dashboard Supabase.

---

## 📌 Ringkasan Biaya Operasional (Cost Breakdown)

| Komponen | Penyedia Layanan | Biaya |
| :--- | :--- | :---: |
| **Database & Auth (BaaS)** | Supabase Free Tier | **Rp 0 / bulan** |
| **Penyimpanan Foto & Dokumen** | Supabase Storage (1 GB) | **Rp 0 / bulan** |
| **Hosting Distribusi APK** | GitHub Releases | **Rp 0 / bulan** |
| **Pendaftaran Toko Baru** | Langsung via Supabase Dashboard | **Rp 0** |
| **Total Biaya Infrastruktur** | — | **Rp 0 (100% GRATIS)** |
