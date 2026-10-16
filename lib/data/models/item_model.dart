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

class ItemModel {
  final String id;
  final String categoryId;
  final String name;
  final int dailyPrice; // harga per hari (integer rupiah)
  final int replacementPrice; // harga ganti bila rusak/hilang
  final int totalStock;
  final int rentedStock;
  final int damagedStock;
  final int minimumStock;
  final String description;
  final bool isActive;
  final List<ProductVariantModel> variants;

  const ItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.dailyPrice,
    required this.replacementPrice,
    this.totalStock = 0,
    this.rentedStock = 0,
    this.damagedStock = 0,
    this.minimumStock = 2,
    this.description = '',
    this.isActive = true,
    this.variants = const [],
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
    int? replacementPrice,
    int? totalStock,
    int? rentedStock,
    int? damagedStock,
    int? minimumStock,
    String? description,
    bool? isActive,
    List<ProductVariantModel>? variants,
  }) {
    return ItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      dailyPrice: dailyPrice ?? this.dailyPrice,
      replacementPrice: replacementPrice ?? this.replacementPrice,
      totalStock: totalStock ?? this.totalStock,
      rentedStock: rentedStock ?? this.rentedStock,
      damagedStock: damagedStock ?? this.damagedStock,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      variants: variants ?? this.variants,
    );
  }
}
