class FeePresetModel {
  final String id;
  final String name;
  final String type; // "kotor", "rusak", "telat", "hilang"
  final int defaultAmount;

  const FeePresetModel({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultAmount,
  });
}

class CashierAccountModel {
  final String id;
  final String name;
  final String email;
  final bool isActive;
  final DateTime createdAt;

  const CashierAccountModel({
    required this.id,
    required this.name,
    required this.email,
    this.isActive = true,
    required this.createdAt,
  });

  CashierAccountModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CashierAccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class StoreSettingsModel {
  // 1 Toko = Maksimal 1 Akun Kasir Aktif
  static const int maxKasirAktif = 1;

  static const List<FeePresetModel> defaultFeePresets = [
    FeePresetModel(id: 'fee_kotor_ringan', name: 'Alat Kotor Ringan (Debu/Tanah Kering)', type: 'kotor', defaultAmount: 15000),
    FeePresetModel(id: 'fee_kotor_lumpur', name: 'Alat Kotor Berat (Lumpur/Basah Pekat)', type: 'kotor', defaultAmount: 30000),
    FeePresetModel(id: 'fee_sobek_tenda', name: 'Sobek Kain Tenda', type: 'rusak', defaultAmount: 50000),
    FeePresetModel(id: 'fee_frame_patah', name: 'Frame Tenda Patah (Per Batang)', type: 'rusak', defaultAmount: 40000),
    FeePresetModel(id: 'fee_tali_putus', name: 'Tali / Buckle Pengait Patah', type: 'rusak', defaultAmount: 15000),
  ];

  final String storeId;
  final String storeName;
  final String subHeader;
  final String storeAddress;
  final String storePhone;
  final String receiptFooter;
  final int minDpPercent; // default 50%
  final bool includePickupDay; // default false
  final int maxCashierDiscountPercent; // default 10%
  final int defaultDepositAmount; // default Rp 100.000
  final int minDepositAmount; // default Rp 50.000
  final int lateFeeRatePercent; // default 100% dari harga per hari
  final int lateGracePeriodDays; // default 0 hari toleransi
  final bool isPremium; // Status paket premium toko
  final List<CashierAccountModel> cashiers;
  final List<FeePresetModel> feePresets;

  const StoreSettingsModel({
    this.storeId = '',
    this.storeName = 'CampRent Outdoor Equipment',
    this.subHeader = 'Pusat Rental Tenda & Alat Gunung Terlengkap',
    this.storeAddress = 'Jl. Kaliurang KM 12, Sleman, DI Yogyakarta',
    this.storePhone = '0812-8899-7700',
    this.receiptFooter = 'Harap periksa kondisi alat saat pengambilan.\nKeterlambatan & kerusakan dikenakan denda sesuai ketentuan.',
    this.minDpPercent = 50,
    this.includePickupDay = false,
    this.maxCashierDiscountPercent = 10,
    this.defaultDepositAmount = 100000,
    this.minDepositAmount = 50000,
    this.lateFeeRatePercent = 100,
    this.lateGracePeriodDays = 0,
    this.isPremium = false,
    this.cashiers = const [],
    this.feePresets = defaultFeePresets,
  });

  int get activeCashierCount => cashiers.where((c) => c.isActive).length;
  bool get isCashierSlotFull => activeCashierCount >= maxKasirAktif;

  StoreSettingsModel copyWith({
    String? storeId,
    String? storeName,
    String? subHeader,
    String? storeAddress,
    String? storePhone,
    String? receiptFooter,
    int? minDpPercent,
    bool? includePickupDay,
    int? maxCashierDiscountPercent,
    int? defaultDepositAmount,
    int? minDepositAmount,
    int? lateFeeRatePercent,
    int? lateGracePeriodDays,
    bool? isPremium,
    List<CashierAccountModel>? cashiers,
    List<FeePresetModel>? feePresets,
  }) {
    return StoreSettingsModel(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      subHeader: subHeader ?? this.subHeader,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      minDpPercent: minDpPercent ?? this.minDpPercent,
      includePickupDay: includePickupDay ?? this.includePickupDay,
      maxCashierDiscountPercent: maxCashierDiscountPercent ?? this.maxCashierDiscountPercent,
      defaultDepositAmount: defaultDepositAmount ?? this.defaultDepositAmount,
      minDepositAmount: minDepositAmount ?? this.minDepositAmount,
      lateFeeRatePercent: lateFeeRatePercent ?? this.lateFeeRatePercent,
      lateGracePeriodDays: lateGracePeriodDays ?? this.lateGracePeriodDays,
      isPremium: isPremium ?? this.isPremium,
      cashiers: cashiers ?? this.cashiers,
      feePresets: feePresets ?? this.feePresets,
    );
  }
}
