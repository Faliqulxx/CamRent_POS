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
  // PRD 5.1: Batas akun kasir aktif = 3
  static const int maxKasirAktif = 3;

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
  final List<CashierAccountModel> cashiers;
  final List<FeePresetModel> feePresets;

  const StoreSettingsModel({
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
    this.cashiers = const [],
    this.feePresets = const [],
  });

  int get activeCashierCount => cashiers.where((c) => c.isActive).length;
  bool get isCashierSlotFull => activeCashierCount >= maxKasirAktif;

  StoreSettingsModel copyWith({
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
    List<CashierAccountModel>? cashiers,
    List<FeePresetModel>? feePresets,
  }) {
    return StoreSettingsModel(
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
      cashiers: cashiers ?? this.cashiers,
      feePresets: feePresets ?? this.feePresets,
    );
  }
}
