class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String note;
  final bool isBlacklisted;
  final String? blacklistReason;
  final int totalRentals;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.note = '',
    this.isBlacklisted = false,
    this.blacklistReason,
    this.totalRentals = 0,
  });

  /// Normalisasi nomor WA ke 62...
  static String normalizePhone(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+62')) {
      cleaned = cleaned.substring(1);
    } else if (!cleaned.startsWith('62') && cleaned.isNotEmpty) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? note,
    bool? isBlacklisted,
    String? blacklistReason,
    int? totalRentals,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      blacklistReason: blacklistReason ?? this.blacklistReason,
      totalRentals: totalRentals ?? this.totalRentals,
    );
  }
}
