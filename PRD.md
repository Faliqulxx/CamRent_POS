# PRD: Aplikasi Kasir Rental Alat Outdoor (Flutter, Online/Offline)

> Dokumen ini dipakai sebagai acuan AI agent saat membangun aplikasi. Kerjakan **per tahap dan per milestone**. Jangan lompat ke tahap berikutnya sebelum acceptance criteria tahap berjalan lulus.

- **Versi:** 2.1
- **Platform:** Android (APK), dibangun dengan Flutter
- **Bahasa UI:** Indonesia
- **Mata uang:** Rupiah (IDR), integer tanpa desimal
- **Zona waktu:** Asia/Jakarta (WIB)

---

## 1. Ringkasan Produk

Aplikasi kasir untuk toko rental alat outdoor (tenda, carrier, sleeping bag, kompor, dll.). Konsepnya **pelanggan datang langsung ke toko** (walk-in), tidak ada pemesanan online.

### Alur bisnis utama
```
PELANGGAN DATANG
  -> Kasir pilih alat + tanggal ambil/kembali
  -> Pelanggan bayar DP 50%
  -> Pelanggan menyerahkan JAMINAN (KTP/SIM/KTM, fisik dipegang toko)
       -> jika tidak ada jaminan: bayar DEPOSIT uang
  -> Sewa aktif, struk dicetak, alat dibawa

PELANGGAN KEMBALI
  -> Kasir CEK alat satu per satu (baik / kotor / rusak / hilang)
  -> Sistem hitung denda (telat + kotor + rusak + hilang)
  -> Pelanggan bayar PELUNASAN (+ denda jika ada)
  -> Jaminan (KTP/SIM/KTM) DIKEMBALIKAN, atau deposit uang dikembalikan
     setelah dipotong tagihan
  -> Sewa selesai, struk pelunasan dicetak
```

### Tujuan
1. Kasir bisa membuat transaksi sewa dalam **kurang dari 1 menit**.
2. Hitungan harga, DP, denda, dan deposit **otomatis dan konsisten**, mengikuti pengaturan owner.
3. Tetap bisa dipakai saat **internet mati** (offline-first), lalu sinkron otomatis.
4. Owner bisa memantau stok dan omzet, dengan hak akses dan log aktivitas untuk mencegah kecurangan.

### Bukan tujuan
Booking online, pembayaran gateway otomatis, iOS/web, multi-cabang, **foto KTP/jaminan**, **foto kondisi kerusakan** (lihat 3.9).

---

## 2. Pengguna dan Hak Akses

| Fitur | Admin (Owner) | Kasir (Staff) |
|---|---|---|
| Dashboard | Lengkap (omzet, laba, grafik) | Ringkas (transaksi hari ini) |
| Sewa baru | Ya | Ya |
| Pengembalian + denda | Ya | Ya |
| Kelola pelanggan | Ya | Tambah/edit saja, tidak bisa hapus |
| Lihat stok alat | Ya | Ya |
| Tambah/edit/hapus alat dan harga | Ya | Tidak |
| Batalkan transaksi | Ya | Tidak (hanya mengajukan) |
| Diskon di atas batas | Ya | Tidak (butuh persetujuan admin) |
| Laporan keuangan | Ya | Tidak |
| Kelola akun kasir (maks. 3 kasir aktif) | Ya | Tidak |
| Pengaturan toko (denda, DP, deposit, nota) | Ya | Tidak |
| Pengaturan printer **di perangkat sendiri** (pilih printer, uji cetak) | Ya | Ya |
| Log aktivitas | Ya | Tidak |

Hak akses **harus ditegakkan di backend** (Row Level Security Supabase), bukan hanya menyembunyikan menu di UI.

---

## 3. Aturan Bisnis (Sumber Kebenaran)

Semua angka di bawah adalah **default yang bisa diubah owner di Pengaturan**. Jangan di-hardcode.

### 3.1 Durasi dan harga sewa
- Sewa dihitung **per tanggal kalender**, jam tidak berpengaruh.
- `jumlah_hari = tanggal_kembali - tanggal_ambil`, minimal **1 hari**.
  - Ambil 10 Okt, kembali 12 Okt = 2 hari.
  - Ambil dan kembali di tanggal yang sama = 1 hari.
- `subtotal_item = harga_per_hari x qty x jumlah_hari`
- `total_sewa = jumlah subtotal_item - diskon`
- Pengaturan opsional: **"Hari ambil dihitung sebagai hari pertama"** (default: nonaktif). Jika aktif, `jumlah_hari = selisih + 1`.

### 3.2 Pembayaran
- Saat **pengambilan**: pelanggan membayar **DP 50%** dari total sewa (persentase minimum bisa diubah owner).
- Saat **pengembalian**: pelunasan sisa sewa + denda (jika ada).
- Metode: tunai, transfer, QRIS (dicatat manual, tanpa integrasi gateway). Satu transaksi boleh punya beberapa pembayaran.
- Kasir boleh menaikkan DP (termasuk lunas di awal), tidak boleh di bawah minimum.

### 3.3 Jaminan dan deposit
- **Jaminan identitas** (KTP / SIM / KTM, daftar jenis bisa diatur owner) dipegang fisik oleh toko selama sewa.
  - Yang dicatat hanya **jenis jaminan** dan **keterangan** (mis. nama pemilik atau 4 digit terakhir nomor). **Tidak ada foto.** Nomor lengkap bersifat opsional agar data pribadi pelanggan seminimal mungkin.
- Jika pelanggan **tidak punya jaminan**, maka **deposit uang wajib**:
  - Nominal default diatur owner di Pengaturan.
  - **Kasir dan owner boleh mengubah nominal** saat transaksi, dengan batas minimum dari pengaturan. Perubahan dicatat di log.
- Saat pengembalian:
  - Jaminan fisik dikembalikan ke pelanggan (status `Dikembalikan`), atau
  - Deposit uang dipakai untuk menutup tagihan terlebih dahulu, sisanya dikembalikan.
- **Aturan penting:** jaminan **tidak boleh** ditandai dikembalikan sebelum pelunasan selesai dan semua item sudah dicek.

### 3.4 Denda (semua dikonfigurasi owner)
Owner mengelola **Master Denda** di Pengaturan. Tiap jenis punya nama, tipe (`nominal` atau `persen`), nilai, dan basis perhitungan.

| Jenis | Perilaku default |
|---|---|
| **Telat** | Per hari telat per item. Owner memilih: persen dari harga sewa per hari item (default 100%) **atau** nominal tetap per hari. |
| **Kotor** | Pilih dari preset (mis. "Cuci tenda", "Cuci sleeping bag"), nominal atau persen. |
| **Rusak** | Pilih dari preset (mis. "Resleting rusak", "Tenda sobek ringan") atau nominal manual. |
| **Hilang** | Default sebesar `harga_ganti` alat. |

Aturan telat:
- Dihitung **per tanggal**: setiap tanggal setelah jatuh tempo = 1 hari telat, apa pun jamnya.
- Dihitung **per item**; item yang sudah kembali tepat waktu tidak kena denda.
- Pengaturan: **masa toleransi** (hari, default 0) dan **batas maksimal denda** (opsional).

Aturan denda manual:
- Kasir memilih preset. Nominal manual di luar preset hanya sampai batas di pengaturan; di atas itu butuh persetujuan admin.
- Setiap denda wajib punya **catatan teks**.

### 3.5 Penyelesaian saat pengembalian
```
total_tagihan = sisa_pelunasan_sewa + total_denda
deposit_dipakai = min(deposit_uang, total_tagihan)
sisa_bayar      = total_tagihan - deposit_dipakai       (dibayar pelanggan)
kembalian_dep   = deposit_uang - deposit_dipakai         (dikembalikan ke pelanggan)
```
Tampilkan ringkasan ini jelas di layar **sebelum** kasir menekan "Selesaikan".

### 3.6 Status transaksi
`Aktif` -> `Dikembalikan sebagian` -> `Selesai`; cabang: `Menunggu persetujuan`, `Dibatalkan`.
- `Telat` adalah **label turunan** (jatuh tempo < hari ini dan belum selesai), bukan status tersimpan.
- Pembatalan oleh kasir = **pengajuan** yang harus disetujui admin.
- Transaksi `Selesai` **tidak boleh diedit**; koreksi lewat catatan penyesuaian oleh admin.

### 3.7 Stok
- Tersedia = `stok_total - sedang_disewa - rusak/maintenance`.
- Stok berkurang saat sewa dibuat, kembali saat alat dikembalikan, kecuali ditandai `Rusak` (masuk stok rusak) atau `Hilang` (mengurangi stok total).
- Sistem **menolak** qty melebihi stok tersedia.
- Karena pelanggan datang langsung, stok dihitung berdasarkan kondisi saat ini (tanpa reservasi tanggal).
- Peringatan stok menipis memakai `stok_minimum` per alat.

### 3.8 Diskon
- Kasir boleh memberi diskon sampai batas di pengaturan. Di atasnya perlu persetujuan admin (pengajuan atau PIN admin di perangkat kasir).

### 3.9 Kebijakan foto dan data pribadi
- **Satu-satunya foto** dalam aplikasi adalah **foto produk/alat** di katalog (opsional, dikompres, maksimal sekitar 200 KB per foto).
- **Tidak ada** foto KTP/SIM/KTM dan **tidak ada** foto kondisi kerusakan. Kondisi alat dicatat dengan teks (kondisi + catatan).
- Data pelanggan seminimal mungkin: nama, nomor WA, catatan.

---

## 4. Ruang Lingkup per Tahap

### Tahap 1 (MVP yang bisa dipakai)
1. Login dan role (Admin, Kasir)
2. Katalog alat, kategori, harga, stok (dengan foto produk)
3. Pelanggan + blacklist
4. Sewa baru (DP, jaminan/deposit)
5. Pengembalian + cek kondisi + denda + pelunasan
6. Pengaturan owner
7. Struk printer thermal (Bluetooth)
8. Offline-first + sinkronisasi
9. Dashboard dan laporan harian
10. Pengajuan pembatalan dan diskon

### Tahap 2
Paket sewa, kirim struk via WhatsApp, laporan bulanan + grafik + ekspor Excel/CSV, layar log aktivitas, pengingat jatuh tempo (notifikasi lokal).

### Tahap 3
Harga musiman, biaya operasional dan laba bersih, tutup kasir (shift), maintenance alat terjadwal.

> **Instruksi untuk agent:** kerjakan Tahap 1 saja. Rancang kode dan skema agar mudah dikembangkan, tetapi jangan membangun fitur Tahap 2/3 sebelum diminta.

---

## 5. Spesifikasi Fitur Tahap 1

### 5.1 Autentikasi dan akun
- Login email/username + password (Supabase Auth). Sesi tersimpan di perangkat agar kasir **tetap bisa masuk saat offline** setelah login pertama.
- Admin membuat, menonaktifkan, mengaktifkan kembali, dan mereset password kasir. Pembuatan akun dilakukan lewat **Supabase Edge Function** (memakai service role di server, bukan dari aplikasi). Akun tidak dihapus permanen.
- **Batas akun kasir: maksimal 3 kasir aktif** pada satu toko.
  - Yang dihitung hanya kasir berstatus **aktif**. Menonaktifkan seorang kasir membebaskan satu slot; mengaktifkan kembali akun lama juga tunduk pada batas ini.
  - Batas ditegakkan **di server** (Edge Function + constraint/trigger database), bukan hanya di UI.
  - Layar Kelola Kasir menampilkan penghitung slot (mis. "2 dari 3 kasir aktif"). Saat penuh, tombol "Tambah kasir" nonaktif disertai penjelasan.
  - Jumlah admin tidak dihitung dalam batas ini (Admin: 1 akun owner).
  - Nilai batas disimpan sebagai konstanta konfigurasi (`MAX_KASIR_AKTIF = 3`) agar mudah diubah di kemudian hari, tetapi **tidak** bisa diubah dari layar pengaturan.
- Role disimpan di tabel `profiles` dan dipakai oleh RLS.
- Seed awal: satu akun admin yang wajib ganti password saat login pertama.

**Acceptance criteria**
- Kasir yang mencoba mengakses data/aksi admin ditolak oleh server.
- Akun nonaktif tidak bisa login atau sinkron.
- Menambah kasir ke-4 (aktif) ditolak oleh server dengan pesan jelas, walau permintaan dikirim langsung ke API.
- Menonaktifkan satu kasir lalu menambah kasir baru berhasil.
- Kasir yang dinonaktifkan tetap muncul di riwayat transaksi dan laporan.

### 5.2 Katalog alat dan stok
Field: nama, kategori, **foto produk (opsional)**, harga per hari, `harga_ganti`, stok total, stok rusak, stok minimum, deskripsi, aktif.
- Kategori: CRUD oleh admin.
- Daftar alat menampilkan tersedia / sedang disewa / rusak, dengan pencarian dan filter kategori.
- Kasir hanya melihat; admin CRUD. Alat yang pernah dipakai transaksi hanya dinonaktifkan, tidak dihapus.

**Acceptance criteria**
- "Tersedia" selalu = total - disewa - rusak.
- Mengubah harga alat **tidak** mengubah transaksi lama (harga disalin/snapshot ke item transaksi).
- Foto produk di-cache lokal agar tampil saat offline.

### 5.3 Pelanggan
Field: nama, no. WhatsApp, alamat (opsional), catatan, status blacklist + alasan.
- Pencarian cepat nama/nomor WA; riwayat sewa per pelanggan.
- Blacklist: peringatan merah saat dipilih; lanjut hanya dengan persetujuan admin.
- Kasir: tambah/edit. Admin: juga hapus (soft delete) dan atur blacklist.
- Normalisasi nomor WA ke format `62...`.

### 5.4 Sewa baru (alur kasir)
1. Pilih atau tambah pelanggan (inline).
2. Pilih tanggal ambil (default hari ini) dan tanggal kembali.
3. Tambah alat (banyak item) dan qty; tampil stok tersedia.
4. Diskon (opsional, sesuai batas).
5. **Jaminan:** pilih KTP/SIM/KTM + keterangan singkat. Jika tidak ada jaminan, form **deposit uang** muncul dan wajib diisi (nominal default dari pengaturan, bisa diubah kasir/owner).
6. **Bayar DP** (default 50%), pilih metode; tampilkan kembalian untuk tunai.
7. Simpan -> status `Aktif`, stok berkurang, struk dicetak.

**Acceptance criteria**
- Total, DP, dan sisa dihitung otomatis sesuai 3.1-3.2 dan identik di layar, struk, dan database.
- Tidak bisa disimpan tanpa jaminan **atau** deposit.
- Nomor transaksi unik dan terbaca manusia, mis. `RNT-20261016-0001`.

### 5.5 Pengembalian, cek barang, dan denda
1. Cari transaksi (nomor, nama, atau no. WA) atau pilih dari daftar "Jatuh tempo hari ini" dan "Telat".
2. **Cek barang per item:** qty kembali, kondisi (`Baik` / `Kotor` / `Rusak` / `Hilang`), catatan teks. Tidak ada upload foto.
3. Sistem menghitung denda telat otomatis; kasir menambah denda kotor/rusak/hilang dari preset atau manual (sesuai 3.4).
4. Tampilkan ringkasan 3.5: sisa pelunasan, denda, deposit dipakai, sisa bayar, atau kembalian deposit.
5. Terima pembayaran.
6. Kasir menekan **"Kembalikan jaminan"** (atau **"Kembalikan deposit"**), lalu "Selesaikan". Status menjadi `Selesai` (atau `Dikembalikan sebagian`).
7. Cetak struk pelunasan.

**Acceptance criteria**
- Pengembalian sebagian didukung; item yang belum kembali tetap `Aktif` dan tetap bisa kena denda telat. Jaminan tetap dipegang sampai **semua item** kembali dan lunas.
- Denda telat per tanggal dan per item, termasuk toleransi dan batas maksimal.
- Alat `Rusak` masuk stok rusak; `Hilang` mengurangi stok total.

### 5.6 Pengaturan owner
- **Toko:** nama, alamat, telepon, footer struk, logo (opsional, hitam-putih untuk struk).
- **Sewa:** DP minimum (%), aturan hitung hari, batas diskon kasir.
- **Denda:** tipe dan nilai denda telat, toleransi, batas maksimal, master preset kotor/rusak, batas denda manual kasir.
- **Deposit:** nominal default, nominal minimum.
- **Jaminan:** daftar jenis yang diterima (default KTP, SIM, KTM).
- **Struk (dipakai bersama semua perangkat):** teks header/footer, tampilkan logo, tampilkan syarat sewa, jumlah salinan default.
- **Printer:** diatur per perangkat di layar Pengaturan Printer (lihat 5.7).

Perubahan pengaturan **hanya berlaku untuk transaksi baru**; transaksi aktif memakai snapshot aturan saat dibuat.

### 5.7 Printer dan struk thermal

#### Pengaturan printer (bisa diatur dari aplikasi)
Layar **Pengaturan > Printer** tersedia untuk Admin **dan** Kasir, karena printer terhubung ke HP masing-masing. Pengaturan printer disimpan **lokal per perangkat** (tidak disinkronkan ke server), sebab alamat Bluetooth berbeda di tiap HP.

| Pengaturan | Keterangan |
|---|---|
| Pilih printer | Daftar perangkat Bluetooth yang sudah dipasangkan (paired) di HP, dengan tombol **Cari/Refresh**. Pilih satu sebagai printer default. |
| Status koneksi | Terhubung / Tidak terhubung / Menyambungkan, dengan tombol **Sambungkan ulang**. |
| Lebar kertas | 58mm atau 80mm. |
| Karakter per baris | Otomatis menurut lebar kertas (mis. 32 untuk 58mm, 48 untuk 80mm), bisa diubah manual. |
| Ukuran/kerapatan font | Normal atau kecil (jika printer mendukung). |
| Jumlah salinan | Default 1, bisa diubah per cetak. |
| Margin bawah / jumlah baris kosong | Agar struk mudah disobek. |
| Potong kertas otomatis | Aktif/nonaktif (jika printer punya auto-cutter). |
| Cetak otomatis | Cetak struk otomatis setelah transaksi disimpan: aktif/nonaktif. |
| Buka laci kasir | Opsional, aktif/nonaktif (jika terhubung). |
| Code page / encoding | Pilihan untuk mengatasi karakter aneh pada printer tertentu (default: PC437/CP858). |
| **Uji cetak** | Tombol untuk mencetak struk contoh (garis ukuran lebar, contoh item, huruf dan angka) agar pengaturan bisa diverifikasi. |

Aturan:
- Aplikasi meminta izin Bluetooth saat pertama kali (termasuk izin Android 12+ `BLUETOOTH_CONNECT` dan `BLUETOOTH_SCAN`) dan menjelaskan alasannya dengan bahasa Indonesia.
- Jika printer belum dipilih saat kasir menekan Cetak, tampilkan dialog **"Pilih printer"** langsung, bukan error.
- Pengaturan printer tetap bisa diubah saat **offline**.
- Hanya satu printer default per perangkat pada Tahap 1.

#### Isi dan format struk
- Cetak langsung ke printer thermal **Bluetooth** (ESC/POS) dengan lebar **58mm atau 80mm** sesuai pengaturan di atas.
- Struk sewa: info toko, nomor transaksi, tanggal, kasir, pelanggan, tanggal ambil/kembali, daftar item (nama, qty, harga/hari, hari, subtotal), diskon, total, DP, sisa, jaminan/deposit, footer.
- Struk pengembalian: kondisi/denda per item, deposit dipakai/dikembalikan, total bayar, status lunas, info jaminan dikembalikan.
- Cetak ulang tercatat di log dan diberi tanda "SALINAN".
- Pencetakan dibuat sebagai **adapter terpisah** (interface `ReceiptPrinter`) sehingga paket printer atau jenis koneksi (Bluetooth, USB, LAN) bisa diganti tanpa mengubah logika struk. Pembuatan isi struk (`ReceiptBuilder`) dipisah dari pengirim ke printer.
- Fallback bila printer tidak terhubung: transaksi tetap tersimpan, struk bisa dicetak ulang kapan saja; opsional bagikan sebagai PDF/gambar.

**Acceptance criteria**
- Pengguna bisa memilih printer, mengganti lebar kertas 58mm/80mm, dan menjalankan uji cetak **tanpa mengubah kode**.
- Struk tidak terpotong di 58mm maupun 80mm.
- Gagal cetak (printer mati/di luar jangkauan) tidak membatalkan transaksi dan menampilkan pesan dengan opsi "Coba lagi" dan "Lewati".
- Setelah aplikasi dibuka ulang, printer terakhir yang dipilih diingat dan mencoba tersambung otomatis.

### 5.8 Offline-first dan sinkronisasi
- **Database lokal (Drift/SQLite) adalah sumber utama untuk UI.** Kasir selalu membaca dan menulis ke lokal, sehingga aplikasi cepat dan tidak bergantung internet.
- Semua perubahan masuk **outbox** dengan UUID buatan klien, dikirim ke Supabase saat online. Sinkron harus **idempoten** (kirim ulang tidak menggandakan data).
- Data yang di-pull ke lokal: katalog alat, stok, pelanggan, pengaturan, transaksi aktif dan riwayat terbaru.
- Penomoran transaksi: nomor menyertakan kode perangkat agar tidak bentrok antar perangkat (mis. `RNT-20261016-A-0001`). Dengan batas 3 kasir + 1 admin, maksimal ada sekitar 4 perangkat aktif; kode perangkat dibuat saat login pertama dan terdaftar di server.
- Indikator status jelas: Online / Offline / Menyinkronkan / Gagal (n item).
- **Konflik stok:** server menjadi sumber kebenaran. Jika sinkron membuat stok negatif, transaksi ditandai `Perlu ditinjau` dan muncul di daftar admin; data tidak boleh hilang.
- Fitur yang **wajib online**: laporan keuangan, pengaturan, kelola akun, persetujuan admin jarak jauh.

**Acceptance criteria**
- Matikan internet, buat 3 sewa dan 1 pengembalian, nyalakan internet: semua tersinkron tanpa duplikat.
- Sinkron dijalankan dua kali tidak membuat data ganda.
- Aplikasi bisa dibuka dan dipakai setelah restart tanpa internet.

### 5.9 Dashboard dan laporan harian
- **Kasir:** jumlah transaksi hari ini, uang masuk per metode, daftar jatuh tempo hari ini dan telat.
- **Admin:** semua di atas + omzet hari/minggu/bulan, alat terlaris, stok menipis.
- **Laporan harian:** pemasukan per metode (DP, pelunasan, denda), sewa baru, pengembalian, deposit yang sedang dipegang, jumlah jaminan yang sedang dipegang.

### 5.10 Persetujuan pembatalan dan diskon
- Kasir mengajukan dengan alasan; admin menyetujui/menolak dengan catatan.
- Pembatalan transaksi aktif mengembalikan stok dan mencatat perlakuan DP (dikembalikan atau hangus) sesuai keputusan admin.
- Semua aksi tercatat di `audit_log` (layar log lengkap di Tahap 2).

---

## 6. Model Data (Garis Besar)

UUID sebagai primary key; `created_at`, `updated_at`, `deleted_at` (soft delete) di tabel utama; uang sebagai **integer rupiah**. Skema sama di Postgres (Supabase) dan SQLite (Drift). Tambahkan kolom `device_id` dan `synced_at` untuk sinkronisasi.

| Tabel | Field penting |
|---|---|
| `profiles` | id (= auth uid), nama, role (`admin`/`kasir`), aktif (kasir aktif dibatasi maks. 3 lewat constraint/trigger) |
| `devices` | id, kode (mis. `A`, `B`), user_id, nama_perangkat, last_seen |
| `categories` | id, nama |
| `items` | id, category_id, nama, foto_url, harga_per_hari, harga_ganti, stok_total, stok_rusak, stok_minimum, aktif |
| `customers` | id, nama, wa, alamat, catatan, blacklist, blacklist_alasan |
| `rentals` | id, nomor, customer_id, kasir_id, tgl_ambil, tgl_kembali, jumlah_hari, subtotal, diskon, total_sewa, dp_dibayar, status, settings_snapshot (JSON), catatan |
| `rental_items` | id, rental_id, item_id, nama_snapshot, harga_snapshot, qty, qty_kembali, tgl_kembali_aktual, kondisi, catatan_kondisi |
| `collaterals` | id, rental_id, jenis (`KTP`/`SIM`/`KTM`/lainnya), keterangan, status (`dipegang`/`dikembalikan`), dikembalikan_at |
| `deposits` | id, rental_id, nominal, nominal_dipakai, nominal_dikembalikan |
| `payments` | id, rental_id, tipe (`dp`/`pelunasan`/`denda`/`deposit`/`refund`), metode (`tunai`/`transfer`/`qris`), nominal, kasir_id, waktu |
| `fee_types` | id, nama, jenis (`telat`/`rusak`/`kotor`/`hilang`), tipe (`nominal`/`persen`), nilai, basis |
| `rental_fees` | id, rental_id, rental_item_id, fee_type_id, nama, nominal, catatan |
| `approvals` | id, tipe (`batal`/`diskon`/`blacklist_override`), rental_id, diajukan_oleh, diputuskan_oleh, status, alasan, catatan |
| `settings` | key, value (JSON), pengaturan bersama (toko, denda, deposit, struk) |
| `printer_settings` (**lokal saja**, tidak disinkron) | printer_id/alamat_bluetooth, nama_printer, lebar_kertas, karakter_per_baris, ukuran_font, salinan, margin_bawah, auto_cut, auto_print, buka_laci, code_page |
| `audit_log` | id, user_id, aksi, entitas, entitas_id, sebelum/sesudah (JSON), waktu |
| `sync_outbox` (lokal) | id, jenis_aksi, payload, status, percobaan, error |

Catatan: tidak ada kolom foto pada `collaterals` maupun `rental_fees`.

---

## 7. Stack Teknologi

Boleh diganti jika ada alasan kuat, tetapi **jelaskan dulu alasannya sebelum mengubah**.

- **Aplikasi:** Flutter (Dart), target Android APK
- **State management:** Riverpod
- **Navigasi:** go_router
- **Database lokal:** Drift (SQLite)
- **Backend gratis:** Supabase (Postgres + Auth + Storage + Edge Functions), paket Free
- **Sinkronisasi:** outbox + pull berbasis `updated_at` (dibangun sendiri). PowerSync bisa dipertimbangkan jika sinkron manual terlalu rumit (cek harga dan batas gratisnya dulu).
- **Deteksi koneksi:** connectivity_plus
- **Printer:** print_bluetooth_thermal + esc_pos_utils_plus (di balik interface `ReceiptPrinter`); izin Bluetooth lewat permission_handler; pengaturan printer lokal disimpan di shared_preferences atau tabel Drift lokal
- **Kompres gambar:** flutter_image_compress (foto produk saja)
- **Testing:** `flutter test` (unit), integration_test untuk alur sewa dan pengembalian

Struktur kode yang disarankan: `lib/core` (tema, util, error), `lib/domain` (**fungsi perhitungan harga/denda/deposit murni tanpa dependensi UI**), `lib/data` (Drift, Supabase, sync), `lib/features/*` (auth, items, customers, rental, return, settings, reports, printing).

**Catatan batas gratis Supabase** (cek ulang di halaman harga resmi sebelum rilis): database 500 MB per project, file 1 GB, 2 project aktif, dan project gratis dijeda otomatis jika tidak ada aktivitas selama 7 hari. Karena ada backup yang tidak bisa diandalkan di paket gratis, sediakan **ekspor data berkala (CSV/JSON)** untuk admin.

---

## 8. Kebutuhan Non-Fungsional

- **Performa:** layar daftar dan pencarian instan (data lokal); simpan transaksi < 1 detik.
- **Keamanan:** RLS di semua tabel; service role key **tidak boleh** ada di aplikasi; validasi input; sesi dan token disimpan aman (flutter_secure_storage).
- **Keandalan:** tidak ada penghapusan permanen data transaksi; transaksi lokal tidak boleh hilang walau aplikasi tertutup mendadak.
- **Kegunaan:** tombol besar, nyaman di HP dan tablet, alur kasir paling sedikit langkah, pesan error bahasa Indonesia yang jelas.
- **Audit:** perubahan harga, pengaturan, denda manual, diskon, deposit, pembatalan, dan cetak ulang tercatat.
- **Ukuran data:** foto produk dikompres agar muat di kuota gratis.

---

## 9. Pengujian dan Definition of Done

Fungsi perhitungan di `lib/domain` **wajib** punya unit test, minimal:

| Kasus | Hasil yang diharapkan |
|---|---|
| Ambil 10 Okt, kembali 12 Okt, 1 item Rp 50.000/hari, qty 1 | 2 hari, total Rp 100.000, DP 50% = Rp 50.000 |
| Ambil dan kembali di tanggal sama | 1 hari |
| Kembali 1 tanggal setelah jatuh tempo (jam berapa pun) | Telat 1 hari |
| Toleransi 1 hari, terlambat 1 hari | Denda Rp 0 |
| Denda telat persen 100%, 2 item, hanya 1 item telat | Denda hanya dari item yang telat |
| Deposit Rp 100.000, tagihan Rp 40.000 | Kembalian deposit Rp 60.000 |
| Deposit Rp 50.000, tagihan Rp 80.000 | Sisa bayar Rp 30.000 |
| Tidak ada jaminan dan tidak ada deposit | Ditolak |
| Semua nilai uang | Integer rupiah, tidak ada desimal |
| Qty melebihi stok | Ditolak |
| Ubah harga alat setelah transaksi dibuat | Transaksi lama tidak berubah |
| Kembalikan jaminan sebelum lunas / sebelum semua item kembali | Ditolak |
| Sinkron outbox dijalankan dua kali | Tidak ada data ganda |
| Menambah kasir aktif ke-4 | Ditolak server |
| Nonaktifkan 1 kasir lalu tambah kasir baru | Berhasil; riwayat kasir lama tetap utuh |
| Ganti lebar kertas 58mm ke 80mm lalu uji cetak | Layout struk menyesuaikan dan tidak terpotong |
| Cetak saat printer belum dipilih / mati | Dialog pilih printer / pesan gagal; transaksi tetap tersimpan |

**Definition of Done tiap milestone:**
1. Fitur sesuai acceptance criteria.
2. Unit test (dan integration test untuk alur utama) lulus.
3. `flutter analyze` bersih, tidak ada error runtime.
4. Hak akses Admin vs Kasir diuji (termasuk di sisi RLS).
5. README diperbarui (cara menjalankan, konfigurasi Supabase, seed data, build APK).

---

## 10. Rencana Milestone Tahap 1 (Urutan Pengerjaan Agent)

| # | Milestone | Isi |
|---|---|---|
| M0 | Setup | Proyek Flutter, struktur folder, lint, Supabase project, skema + migrasi, seed admin |
| M1 | Domain engine | Fungsi harga, DP, denda, deposit + unit test lengkap |
| M2 | Database lokal | Drift schema, repository, dasar outbox |
| M3 | Auth dan role | Login (online + sesi offline), RLS, Edge Function kelola kasir dengan batas 3 kasir aktif |
| M4 | Master data | Kategori, alat (foto produk), stok, pelanggan, blacklist |
| M5 | Pengaturan | Halaman pengaturan owner (denda, DP, deposit, jaminan, struk) dan layar Kelola Kasir |
| M6 | Sewa baru | Alur kasir lengkap: jaminan/deposit, DP |
| M7 | Pengembalian | Cek kondisi per item, denda, pelunasan, pengembalian jaminan/deposit, pengembalian sebagian |
| M8 | Printer dan struk thermal | Layar Pengaturan Printer (pilih printer, lebar kertas, uji cetak, dll.), adapter Bluetooth, layout 58/80mm, cetak ulang |
| M9 | Sinkronisasi | Push/pull lengkap, idempoten, indikator status, penanganan konflik stok |
| M10 | Persetujuan dan audit | Pengajuan batal/diskon, audit log dasar |
| M11 | Dashboard dan laporan harian | Tampilan kasir dan admin |
| M12 | Hardening dan rilis | Integration test, uji offline penuh, uji printer nyata, build APK, dokumentasi |

**Cara kerja agent:** di awal tiap milestone tulis rencana singkat dan daftar file yang akan diubah; di akhir ringkas apa yang selesai, apa yang diuji, dan apa yang perlu keputusan manusia.

---

## 11. Asumsi dan Pertanyaan Terbuka

**Asumsi (bisa diubah owner):**
- Satu toko dan satu mata uang; pelanggan selalu datang langsung.
- Transfer dan QRIS dicatat manual oleh kasir.
- Nomor/keterangan jaminan opsional demi meminimalkan data pribadi.
- Perangkat kasir Android dengan Bluetooth untuk printer; printer dipasangkan (paired) lebih dulu lewat pengaturan Bluetooth Android.
- Satu akun owner (admin) dan maksimal 3 kasir aktif, sehingga paling banyak sekitar 4 perangkat memakai aplikasi.

**Perlu keputusan:**
1. Mode deposit: nominal tetap per transaksi atau per jenis alat?
2. "Hari ambil" dihitung sebagai hari pertama? (default: tidak)
3. Jika transaksi dibatalkan, DP dikembalikan atau hangus? (default: diputuskan admin per kasus)
4. Merek/model printer yang dimiliki (hanya untuk uji kompatibilitas; pengaturan printer sudah bisa diubah dari aplikasi, jadi bukan penghalang pembangunan).

---

## 12. Glosarium

- **DP:** uang muka sewa, default 50% dari total sewa, dibayar saat ambil.
- **Jaminan:** KTP/SIM/KTM fisik yang dipegang toko selama sewa dan dikembalikan setelah cek barang dan pelunasan.
- **Deposit:** uang jaminan, hanya jika pelanggan tidak menyerahkan jaminan identitas.
- **Outbox:** antrean aksi yang dibuat saat offline dan dikirim ke server saat online.
- **Idempoten:** operasi yang bila dikirim berulang tetap menghasilkan satu hasil yang sama.
- **RLS:** Row Level Security, aturan akses per baris data di Postgres/Supabase.
