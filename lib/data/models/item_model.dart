class CategoryModel {
  final String id;
  final String name;
  final bool requiresSize;

  const CategoryModel({
    required this.id,
    required this.name,
    this.requiresSize = false,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    bool? requiresSize,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      requiresSize: requiresSize ?? this.requiresSize,
    );
  }
}

class ProductVariantModel {
  final String id;
  final String size; // e.g. "39", "40", "S", "M", "L", "XL"
  final int stock; // Total stok untuk varian ukuran ini
  final int rentedStock; // Sedang disewa
  final int damagedStock; // Rusak / perawatan
  final int? dailyPrice; // Harga override per varian (opsional, default harga produk)

  const ProductVariantModel({
    required this.id,
    required this.size,
    required this.stock,
    this.rentedStock = 0,
    this.damagedStock = 0,
    this.dailyPrice,
  });

  int get availableStock {
    final avail = stock - rentedStock - damagedStock;
    return avail > 0 ? avail : 0;
  }

  ProductVariantModel copyWith({
    String? id,
    String? size,
    int? stock,
    int? rentedStock,
    int? damagedStock,
    int? dailyPrice,
  }) {
    return ProductVariantModel(
      id: id ?? this.id,
      size: size ?? this.size,
      stock: stock ?? this.stock,
      rentedStock: rentedStock ?? this.rentedStock,
      damagedStock: damagedStock ?? this.damagedStock,
      dailyPrice: dailyPrice ?? this.dailyPrice,
    );
  }
}

class DurationPriceRule {
  final int days; // Threshold hari rental (misalnya: 1, 2, 7)
  final int pricePerDay; // Harga per hari untuk durasi ini (misal: 20000)
  final bool isActive; // Status aktif aturan
  final bool isPremium; // Apakah merupakan tier premium

  const DurationPriceRule({
    required this.days,
    required this.pricePerDay,
    this.isActive = true,
    this.isPremium = false,
  });

  /// Status efektivitas aturan:
  /// Aturan hanya berlaku jika isActive == true.
  /// Jika isPremium == true, aturan hanya aktif apabila status premium toko telah dibuka (isStorePremium == true).
  bool isEffectiveActive({bool isStorePremium = false}) {
    if (!isActive) return false;
    if (isPremium && !isStorePremium) return false;
    return true;
  }

  DurationPriceRule copyWith({
    int? days,
    int? pricePerDay,
    bool? isActive,
    bool? isPremium,
  }) {
    return DurationPriceRule(
      days: days ?? this.days,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  Map<String, dynamic> toJson() => {
    'days': days,
    'price_per_day': pricePerDay,
    'is_active': isActive,
    'is_premium': isPremium,
  };

  factory DurationPriceRule.fromJson(Map<String, dynamic> json) => DurationPriceRule(
    days: (json['days'] as num?)?.toInt() ?? 1,
    pricePerDay: (json['price_per_day'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] as bool? ?? true,
    isPremium: json['is_premium'] as bool? ?? false,
  );
}

class ItemModel {
  final String id;
  final String categoryId;
  final String name;
  final int dailyPrice; // harga sewa 1 hari (integer rupiah)
  final int? priceTwoOrMoreDays; // harga sewa 2 hari atau lebih (integer rupiah)
  final int replacementPrice; // harga ganti bila rusak/hilang
  final int totalStock;
  final int rentedStock;
  final int damagedStock;
  final int minimumStock;
  final String description;
  final bool isActive;
  final List<ProductVariantModel> variants;
  final List<DurationPriceRule> durationPricing;

  const ItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.dailyPrice,
    this.priceTwoOrMoreDays,
    required this.replacementPrice,
    this.totalStock = 0,
    this.rentedStock = 0,
    this.damagedStock = 0,
    this.minimumStock = 2,
    this.description = '',
    this.isActive = true,
    this.variants = const [],
    this.durationPricing = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

  int get effectiveTotalStock {
    if (hasVariants) {
      return variants.fold(0, (sum, v) => sum + v.stock);
    }
    return totalStock;
  }

  int get effectiveRentedStock {
    if (hasVariants) {
      return variants.fold(0, (sum, v) => sum + v.rentedStock);
    }
    return rentedStock;
  }

  int get effectiveDamagedStock {
    if (hasVariants) {
      return variants.fold(0, (sum, v) => sum + v.damagedStock);
    }
    return damagedStock;
  }

  /// PRD 3.7: Tersedia = stok_total - sedang_disewa - rusak/maintenance
  int get availableStock {
    if (hasVariants) {
      return variants.fold(0, (sum, v) => sum + v.availableStock);
    }
    final avail = totalStock - rentedStock - damagedStock;
    return avail > 0 ? avail : 0;
  }

  bool get isLowStock => availableStock <= minimumStock && availableStock > 0;
  bool get isOutOfStock => availableStock <= 0;

  /// Harga sewa untuk 2 hari atau lebih (default ke 2+ hari rule jika ada dan > 0, atau fallback ke dailyPrice)
  int get effectivePriceTwoOrMoreDays {
    if (priceTwoOrMoreDays != null && priceTwoOrMoreDays! > 0) {
      return priceTwoOrMoreDays!;
    }
    // Kompatibilitas data lama: ambil tier dengan hari >= 2 dan pricePerDay > 0
    final activeTiers = durationPricing.where((r) => r.days >= 2 && r.isActive && r.pricePerDay > 0).toList();
    if (activeTiers.isNotEmpty) {
      activeTiers.sort((a, b) => a.days.compareTo(b.days));
      return activeTiers.first.pricePerDay;
    }
    return dailyPrice;
  }

  /// Mencari aturan tier aktif untuk kompatibilitas UI/eksternal
  DurationPriceRule? getActiveTierForDuration(int days, {bool isStorePremium = false}) {
    if (days <= 1) {
      return DurationPriceRule(days: 1, pricePerDay: dailyPrice, isActive: true);
    }
    final p2 = effectivePriceTwoOrMoreDays > 0 ? effectivePriceTwoOrMoreDays : dailyPrice;
    return DurationPriceRule(days: 2, pricePerDay: p2, isActive: true);
  }

  /// Hitung harga per hari berdasarkan 2 aturan durasi:
  /// - Tepat 1 hari: dailyPrice (harga 1 hari)
  /// - 2 hari atau lebih: effectivePriceTwoOrMoreDays (harga 2+ hari)
  int getPriceForDuration(int days, {bool isStorePremium = false}) {
    if (days <= 1) {
      return dailyPrice;
    }
    final p2 = effectivePriceTwoOrMoreDays;
    return p2 > 0 ? p2 : dailyPrice;
  }

  /// Menghitung total harga rental (durasi * tarif per hari * qty)
  int calculateTotalPrice(int days, {bool isStorePremium = false, int qty = 1}) {
    final d = days > 0 ? days : 1;
    final rate = getPriceForDuration(d, isStorePremium: isStorePremium);
    return rate * d * qty;
  }

  String get sizesSummary {
    if (!hasVariants) return 'Tidak ada';
    if (variants.length <= 4) {
      return variants.map((v) => v.size).join('   ');
    }
    final firstFour = variants.take(4).map((v) => v.size).join(', ');
    final remaining = variants.length - 4;
    return '$firstFour +$remaining ukuran';
  }

  ItemModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    int? dailyPrice,
    int? priceTwoOrMoreDays,
    int? replacementPrice,
    int? totalStock,
    int? rentedStock,
    int? damagedStock,
    int? minimumStock,
    String? description,
    bool? isActive,
    List<ProductVariantModel>? variants,
    List<DurationPriceRule>? durationPricing,
  }) {
    return ItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      dailyPrice: dailyPrice ?? this.dailyPrice,
      priceTwoOrMoreDays: priceTwoOrMoreDays ?? this.priceTwoOrMoreDays,
      replacementPrice: replacementPrice ?? this.replacementPrice,
      totalStock: totalStock ?? this.totalStock,
      rentedStock: rentedStock ?? this.rentedStock,
      damagedStock: damagedStock ?? this.damagedStock,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      variants: variants ?? this.variants,
      durationPricing: durationPricing ?? this.durationPricing,
    );
  }
}
