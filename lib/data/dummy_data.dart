import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/data/models/shift_model.dart';

class DummyData {
  // Categories
  static const List<CategoryModel> categories = [
    CategoryModel(id: 'cat_all', name: 'Semua Kategori', requiresSize: false),
    CategoryModel(id: 'cat_tenda', name: 'Tenda & Shelter', requiresSize: false),
    CategoryModel(id: 'cat_sepatu', name: 'Sepatu Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_sandal', name: 'Sandal', requiresSize: true),
    CategoryModel(id: 'cat_jaket', name: 'Jaket & Outerwear', requiresSize: true),
    CategoryModel(id: 'cat_celana', name: 'Celana Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_pakaian', name: 'Pakaian Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_sarung_tangan', name: 'Sarung Tangan', requiresSize: true),
    CategoryModel(id: 'cat_sleeping', name: 'Sleeping Gear', requiresSize: false),
    CategoryModel(id: 'cat_furniture', name: 'Camping Furniture', requiresSize: false),
    CategoryModel(id: 'cat_cooking', name: 'Cooking & Dining', requiresSize: false),
    CategoryModel(id: 'cat_penerangan', name: 'Penerangan', requiresSize: false),
    CategoryModel(id: 'cat_elektronik', name: 'Elektronik Outdoor', requiresSize: false),
    CategoryModel(id: 'cat_survival', name: 'Survival & Safety', requiresSize: false),
    CategoryModel(id: 'cat_pendukung', name: 'Peralatan Pendukung', requiresSize: false),
  ];

  // Items
  static final List<ItemModel> items = [
    const ItemModel(
      id: 'itm_001',
      categoryId: 'cat_tenda',
      name: 'Tenda Camping 4P',
      dailyPrice: 75000,
      replacementPrice: 650000,
      totalStock: 5,
      rentedStock: 1,
      damagedStock: 0,
      minimumStock: 1,
      description: 'Kapasitas 4 orang, double layer waterproof 3000mm, alloy pole kuat.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_002',
      categoryId: 'cat_sepatu',
      name: 'Sepatu Hiking Eiger',
      dailyPrice: 35000,
      replacementPrice: 450000,
      minimumStock: 2,
      description: 'Sepatu gunung tahan air dengan grip outsole vibram kokoh.',
      variants: [
        ProductVariantModel(id: 'var_002_39', size: '39', stock: 2, rentedStock: 0),
        ProductVariantModel(id: 'var_002_40', size: '40', stock: 3, rentedStock: 1),
        ProductVariantModel(id: 'var_002_41', size: '41', stock: 4, rentedStock: 1),
        ProductVariantModel(id: 'var_002_42', size: '42', stock: 2, rentedStock: 0),
      ],
    ),
    const ItemModel(
      id: 'itm_003',
      categoryId: 'cat_sandal',
      name: 'Sandal Gunung Akasaka',
      dailyPrice: 15000,
      replacementPrice: 150000,
      minimumStock: 2,
      description: 'Sandal outdoor strap webbing tubular nyaman dan anti selip.',
      variants: [
        ProductVariantModel(id: 'var_003_38', size: '38', stock: 2),
        ProductVariantModel(id: 'var_003_39', size: '39', stock: 3),
        ProductVariantModel(id: 'var_003_40', size: '40', stock: 3),
        ProductVariantModel(id: 'var_003_41', size: '41', stock: 2),
      ],
    ),
    const ItemModel(
      id: 'itm_004',
      categoryId: 'cat_jaket',
      name: 'Jaket Outdoor Windproof',
      dailyPrice: 30000,
      replacementPrice: 300000,
      minimumStock: 2,
      description: 'Jaket gunung bahan taslan tahan angin dan cipratan air.',
      variants: [
        ProductVariantModel(id: 'var_004_S', size: 'S', stock: 2),
        ProductVariantModel(id: 'var_004_M', size: 'M', stock: 3),
        ProductVariantModel(id: 'var_004_L', size: 'L', stock: 4),
        ProductVariantModel(id: 'var_004_XL', size: 'XL', stock: 2),
      ],
    ),
    const ItemModel(
      id: 'itm_005',
      categoryId: 'cat_cooking',
      name: 'Kompor Portable MSR',
      dailyPrice: 25000,
      replacementPrice: 300000,
      totalStock: 8,
      rentedStock: 2,
      damagedStock: 0,
      minimumStock: 2,
      description: 'Kompor gas portable windproof tahan terpaan angin gunung.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_006',
      categoryId: 'cat_sleeping',
      name: 'Sleeping Bag Mummy',
      dailyPrice: 20000,
      replacementPrice: 200000,
      totalStock: 15,
      rentedStock: 4,
      damagedStock: 1,
      minimumStock: 3,
      description: 'Model mummy thermal sintetis, batas kenyamanan suhu 5-10 derajat.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_007',
      categoryId: 'cat_furniture',
      name: 'Kursi Lipat Camping',
      dailyPrice: 15000,
      replacementPrice: 160000,
      totalStock: 12,
      rentedStock: 3,
      damagedStock: 0,
      minimumStock: 2,
      description: 'Rangka alloy kokoh menahan beban hingga 120kg, ringkas dibawa.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_008',
      categoryId: 'cat_penerangan',
      name: 'Headlamp 500 Lumens',
      dailyPrice: 10000,
      replacementPrice: 90000,
      totalStock: 18,
      rentedStock: 4,
      damagedStock: 0,
      minimumStock: 3,
      description: 'Lampu kepala LED sensor gerak, waterproof, baterai USB type-C.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_009',
      categoryId: 'cat_pendukung',
      name: 'Trekking Pole Ultralight',
      dailyPrice: 15000,
      replacementPrice: 150000,
      totalStock: 10,
      rentedStock: 2,
      damagedStock: 0,
      minimumStock: 2,
      description: 'Bahan aluminium alloy 7075 sepasang, anti-shock lock system.',
      variants: [],
    ),
    const ItemModel(
      id: 'itm_010',
      categoryId: 'cat_celana',
      name: 'Celana Outdoor Quickdry',
      dailyPrice: 25000,
      replacementPrice: 250000,
      minimumStock: 2,
      description: 'Bahan stretch elastis, cepat kering, dan lentur saat mendaki.',
      variants: [
        ProductVariantModel(id: 'var_010_S', size: 'S', stock: 2),
        ProductVariantModel(id: 'var_010_M', size: 'M', stock: 3),
        ProductVariantModel(id: 'var_010_L', size: 'L', stock: 4),
        ProductVariantModel(id: 'var_010_XL', size: 'XL', stock: 2),
      ],
    ),
  ];

  // Customers
  static final List<CustomerModel> customers = [
    const CustomerModel(
      id: 'cust_001',
      name: 'Dimas Pratama',
      phone: '6281234567890',
      address: 'Jl. Gejayan No. 45, Sleman',
      note: 'Pelanggan setia pendakian Merbabu',
      totalRentals: 8,
      isBlacklisted: false,
    ),
    const CustomerModel(
      id: 'cust_002',
      name: 'Rian Hidayat',
      phone: '6285678901234',
      address: 'Perum Candi Indah B-12',
      note: 'Komunitas Mapala Kampus',
      totalRentals: 3,
      isBlacklisted: false,
    ),
    const CustomerModel(
      id: 'cust_003',
      name: 'Fajar Nugraha',
      phone: '6287711223344',
      address: 'Jl. Palagan Tentara Pelajar',
      note: 'Perlu pengawasan',
      totalRentals: 1,
      isBlacklisted: true,
      blacklistReason: 'Pernah kembalikan tenda sobek dan menolak bayar denda pada 12 Sept 2026',
    ),
    const CustomerModel(
      id: 'cust_004',
      name: 'Siti Rahmawati',
      phone: '6281399887766',
      address: 'Jl. Kaliurang KM 8',
      note: 'Penyewa tertib dan tepat waktu',
      totalRentals: 5,
      isBlacklisted: false,
    ),
    const CustomerModel(
      id: 'cust_005',
      name: 'Bayu Setiawan',
      phone: '6285811224455',
      address: 'Gamping, Sleman',
      note: 'Sering sewa carrier dan sleeping bag',
      totalRentals: 2,
      isBlacklisted: false,
    ),
  ];

  // Fee presets
  static const List<FeePresetModel> feePresets = [
    FeePresetModel(id: 'fee_cuci_tenda', name: 'Cuci Tenda (Kotor/Lumpur)', type: 'kotor', defaultAmount: 25000),
    FeePresetModel(id: 'fee_cuci_sb', name: 'Cuci Sleeping Bag', type: 'kotor', defaultAmount: 15000),
    FeePresetModel(id: 'fee_cuci_carrier', name: 'Cuci Carrier / Tas', type: 'kotor', defaultAmount: 20000),
    FeePresetModel(id: 'fee_resleting', name: 'Resleting Rusak / Macet', type: 'rusak', defaultAmount: 30000),
    FeePresetModel(id: 'fee_sobek_tenda', name: 'Sobek Kain Tenda', type: 'rusak', defaultAmount: 50000),
    FeePresetModel(id: 'fee_frame_patah', name: 'Frame Tenda Patah (Per Batang)', type: 'rusak', defaultAmount: 40000),
    FeePresetModel(id: 'fee_tali_putus', name: 'Tali / Buckle Pengait Patah', type: 'rusak', defaultAmount: 15000),
  ];

  // Cashier Accounts (PRD 5.1: 2 dari 3 aktif)
  static final List<CashierAccountModel> cashiers = [
    CashierAccountModel(
      id: 'cashier_001',
      name: 'Budi Santoso',
      email: 'budi.kasir@camprent.com',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    CashierAccountModel(
      id: 'cashier_002',
      name: 'Siti Amelia',
      email: 'siti.kasir@camprent.com',
      isActive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    CashierAccountModel(
      id: 'cashier_003',
      name: 'Ahmad Fauzi',
      email: 'fauzi.kasir@camprent.com',
      isActive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  ];

  // Initial Rentals
  static List<RentalModel> getInitialRentals() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // 1. Rental Aktif - Jatuh Tempo Hari Ini
      RentalModel(
        id: 'rnt_001',
        rentalNumber: 'RNT-20261014-A-0001',
        customer: customers[0], // Dimas
        cashierName: 'Budi Santoso',
        pickupDate: today.subtract(const Duration(days: 2)),
        scheduledReturnDate: today, // Hari ini
        durationDays: 2,
        subtotal: 150000,
        discount: 0,
        totalSewa: 150000,
        dpPaid: 75000,
        status: RentalStatus.aktif,
        collateral: const CollateralModel(
          type: CollateralType.ktp,
          note: 'KTP Asli a.n Dimas Pratama (0412)',
          isReturned: false,
        ),
        deposit: null,
        items: const [
          RentalItemModel(
            id: 'ri_001',
            itemId: 'itm_001',
            nameSnapshot: 'Tenda Dome 4P Peak Horizon',
            priceSnapshot: 50000,
            replacementPriceSnapshot: 550000,
            qty: 1,
          ),
          RentalItemModel(
            id: 'ri_002',
            itemId: 'itm_003',
            nameSnapshot: 'Kompor MSR Windproof + Nesting',
            priceSnapshot: 25000,
            replacementPriceSnapshot: 300000,
            qty: 1,
          ),
        ],
        payments: [
          PaymentRecord(
            id: 'pay_001',
            type: PaymentType.dp,
            method: PaymentMethod.tunai,
            amount: 75000,
            time: today.subtract(const Duration(days: 2, hours: -10)),
            cashierName: 'Budi Santoso',
          ),
        ],
        note: 'Rencana naik Gunung Merbabu jalur Selo',
      ),

      // 2. Rental Aktif - TELAT 2 HARI (Denda Telat)
      RentalModel(
        id: 'rnt_002',
        rentalNumber: 'RNT-20261011-A-0002',
        customer: customers[4], // Bayu Setiawan
        cashierName: 'Siti Amelia',
        pickupDate: today.subtract(const Duration(days: 5)),
        scheduledReturnDate: today.subtract(const Duration(days: 2)), // Telat 2 hari!
        durationDays: 3,
        subtotal: 165000,
        discount: 0,
        totalSewa: 165000,
        dpPaid: 85000,
        status: RentalStatus.aktif,
        collateral: null,
        deposit: const DepositModel(
          amount: 100000, // Deposit uang
          usedAmount: 0,
          refundedAmount: 0,
        ),
        items: const [
          RentalItemModel(
            id: 'ri_003',
            itemId: 'itm_002',
            nameSnapshot: 'Carrier 60L Trekmaster Pro',
            priceSnapshot: 35000,
            replacementPriceSnapshot: 450000,
            qty: 1,
          ),
          RentalItemModel(
            id: 'ri_004',
            itemId: 'itm_004',
            nameSnapshot: 'Sleeping Bag Mummy Hyalite',
            priceSnapshot: 20000,
            replacementPriceSnapshot: 200000,
            qty: 1,
          ),
        ],
        payments: [
          PaymentRecord(
            id: 'pay_002',
            type: PaymentType.dp,
            method: PaymentMethod.qris,
            amount: 85000,
            time: today.subtract(const Duration(days: 5, hours: -14)),
            cashierName: 'Siti Amelia',
          ),
          PaymentRecord(
            id: 'pay_003',
            type: PaymentType.deposit,
            method: PaymentMethod.tunai,
            amount: 100000,
            time: today.subtract(const Duration(days: 5, hours: -14)),
            cashierName: 'Siti Amelia',
          ),
        ],
        note: 'Tanpa jaminan KTP, menggunakan deposit tunai Rp 100.000',
      ),

      // 3. Rental Selesai (Riwayat Sukses)
      RentalModel(
        id: 'rnt_003',
        rentalNumber: 'RNT-20261008-A-0003',
        customer: customers[3], // Siti Rahmawati
        cashierName: 'Budi Santoso',
        pickupDate: today.subtract(const Duration(days: 8)),
        scheduledReturnDate: today.subtract(const Duration(days: 6)),
        actualReturnDate: today.subtract(const Duration(days: 6)),
        durationDays: 2,
        subtotal: 100000,
        discount: 10000,
        totalSewa: 90000,
        dpPaid: 50000,
        status: RentalStatus.selesai,
        collateral: CollateralModel(
          type: CollateralType.sim,
          note: 'SIM A a.n Siti Rahmawati',
          isReturned: true,
          returnedAt: today.subtract(const Duration(days: 6)),
        ),
        deposit: null,
        items: const [
          RentalItemModel(
            id: 'ri_005',
            itemId: 'itm_001',
            nameSnapshot: 'Tenda Dome 4P Peak Horizon',
            priceSnapshot: 50000,
            replacementPriceSnapshot: 550000,
            qty: 1,
            returnedQty: 1,
            condition: ItemCondition.baik,
          ),
        ],
        payments: [
          PaymentRecord(
            id: 'pay_004',
            type: PaymentType.dp,
            method: PaymentMethod.transfer,
            amount: 50000,
            time: today.subtract(const Duration(days: 8)),
            cashierName: 'Budi Santoso',
          ),
          PaymentRecord(
            id: 'pay_005',
            type: PaymentType.pelunasan,
            method: PaymentMethod.tunai,
            amount: 40000,
            time: today.subtract(const Duration(days: 6)),
            cashierName: 'Budi Santoso',
          ),
        ],
        note: 'Selesai tepat waktu, kondisi alat sangat baik',
      ),

      // 4. Rental Menunggu Persetujuan (Diskon khusus 25%)
      RentalModel(
        id: 'rnt_004',
        rentalNumber: 'RNT-20261016-A-0004',
        customer: customers[1], // Rian Hidayat (Mapala)
        cashierName: 'Budi Santoso',
        pickupDate: today,
        scheduledReturnDate: today.add(const Duration(days: 3)),
        durationDays: 3,
        subtotal: 210000,
        discount: 50000, // di atas batas kasir 10%
        totalSewa: 160000,
        dpPaid: 80000,
        status: RentalStatus.menungguPersetujuan,
        collateral: const CollateralModel(
          type: CollateralType.ktm,
          note: 'KTM Ketua Mapala UGM',
          isReturned: false,
        ),
        deposit: null,
        items: const [
          RentalItemModel(
            id: 'ri_006',
            itemId: 'itm_002',
            nameSnapshot: 'Carrier 60L Trekmaster Pro',
            priceSnapshot: 35000,
            replacementPriceSnapshot: 450000,
            qty: 2,
          ),
        ],
        payments: const [],
        note: 'Pengajuan diskon Mapala Kampus 25% (butuh persetujuan Owner)',
      ),
    ];
  }

  // Initial Shifts for Shift Management (Owner & Kasir)
  static List<CashierShiftModel> getInitialShifts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // 1. Shift Aktif Hari Ini (Siti Amelia)
      CashierShiftModel(
        id: 'shf_001',
        cashierId: 'cashier_002',
        cashierName: 'Siti Amelia',
        cashierEmail: 'siti.kasir@camprent.com',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 8, 30),
        endTime: null,
        initialCash: 200000,
        totalTransactions: 3,
        totalCashPayments: 190000,
        totalTransferPayments: 80000,
        totalQrisPayments: 85000,
        cashExpenses: 0,
        actualCash: null,
        status: ShiftStatus.sedangBerjalan,
      ),

      // 2. Shift Selesai Hari Ini (Budi Santoso - Kas Sesuai)
      CashierShiftModel(
        id: 'shf_002',
        cashierId: 'cashier_001',
        cashierName: 'Budi Santoso',
        cashierEmail: 'budi.kasir@camprent.com',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 7, 0),
        endTime: DateTime(today.year, today.month, today.day, 14, 0),
        initialCash: 200000,
        totalTransactions: 5,
        totalCashPayments: 350000,
        totalTransferPayments: 120000,
        totalQrisPayments: 90000,
        cashExpenses: 15000,
        actualCash: 535000, // 200k + 350k - 15k = 535k (selisih 0)
        discrepancyNote: null,
        status: ShiftStatus.selesai,
      ),

      // 3. Shift Selesai Kemarin (Siti Amelia - Kas Lebih)
      CashierShiftModel(
        id: 'shf_003',
        cashierId: 'cashier_002',
        cashierName: 'Siti Amelia',
        cashierEmail: 'siti.kasir@camprent.com',
        date: today.subtract(const Duration(days: 1)),
        startTime: DateTime(today.year, today.month, today.day - 1, 9, 0),
        endTime: DateTime(today.year, today.month, today.day - 1, 17, 30),
        initialCash: 150000,
        totalTransactions: 6,
        totalCashPayments: 420000,
        totalTransferPayments: 150000,
        totalQrisPayments: 65000,
        cashExpenses: 0,
        actualCash: 580000, // 150k + 420k = 570k (selisih +10.000)
        discrepancyNote: 'Kelebihan uang Rp 10.000 dari pelanggan yang tidak mengambil uang kembalian receh.',
        status: ShiftStatus.selesai,
      ),

      // 4. Shift Selesai 2 Hari Lalu (Budi Santoso - Kas Kurang)
      CashierShiftModel(
        id: 'shf_004',
        cashierId: 'cashier_001',
        cashierName: 'Budi Santoso',
        cashierEmail: 'budi.kasir@camprent.com',
        date: today.subtract(const Duration(days: 2)),
        startTime: DateTime(today.year, today.month, today.day - 2, 8, 0),
        endTime: DateTime(today.year, today.month, today.day - 2, 16, 0),
        initialCash: 200000,
        totalTransactions: 4,
        totalCashPayments: 280000,
        totalTransferPayments: 90000,
        totalQrisPayments: 50000,
        cashExpenses: 0,
        actualCash: 475000, // 200k + 280k = 480k (selisih -5.000)
        discrepancyNote: 'Kekurangan Rp 5.000 karena salah pecahan saat memberikan uang kembalian tunai.',
        status: ShiftStatus.selesai,
      ),

      // 5. Kasir Belum Buka Shift (Ahmad Fauzi)
      CashierShiftModel(
        id: 'shf_005',
        cashierId: 'cashier_003',
        cashierName: 'Ahmad Fauzi',
        cashierEmail: 'fauzi.kasir@camprent.com',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 0, 0),
        endTime: null,
        initialCash: 0,
        totalTransactions: 0,
        totalCashPayments: 0,
        totalTransferPayments: 0,
        totalQrisPayments: 0,
        cashExpenses: 0,
        actualCash: null,
        status: ShiftStatus.belumBuka,
      ),
    ];
  }
}
