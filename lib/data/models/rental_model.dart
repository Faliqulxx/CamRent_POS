import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/domain/calculator.dart';

enum ItemCondition {
  baik, // Baik
  kotor, // Perlu cuci / kotor
  rusak, // Rusak sebagian / butuh perbaikan
  hilang, // Hilang total
}

enum RentalStatus {
  aktif, // Sedang disewa
  dikembalikanSebagian,
  selesai, // Sudah kembali dan lunas
  menungguPersetujuan, // Pembatalan / diskon khusus butuh admin
  dibatalkan,
}

enum PaymentType {
  dp,
  pelunasan,
  denda,
  deposit,
  refund,
}

enum PaymentMethod {
  tunai,
  transfer,
  qris,
}

enum CollateralType {
  ktp,
  sim,
  ktm,
  paspor,
  lainnya,
}

class RentalItemModel {
  final String id;
  final String itemId;
  final String nameSnapshot;
  final String? selectedSize;
  final int priceSnapshot;
  final int replacementPriceSnapshot;
  final int qty;
  final int returnedQty;
  final ItemCondition condition;
  final String conditionNote;
  final int fineAmount;

  const RentalItemModel({
    required this.id,
    required this.itemId,
    required this.nameSnapshot,
    this.selectedSize,
    required this.priceSnapshot,
    required this.replacementPriceSnapshot,
    required this.qty,
    this.returnedQty = 0,
    this.condition = ItemCondition.baik,
    this.conditionNote = '',
    this.fineAmount = 0,
  });

  String get displayName => selectedSize != null ? '$nameSnapshot (Ukuran $selectedSize)' : nameSnapshot;

  int get subtotal => priceSnapshot * qty;

  RentalItemModel copyWith({
    String? id,
    String? itemId,
    String? nameSnapshot,
    String? selectedSize,
    int? priceSnapshot,
    int? replacementPriceSnapshot,
    int? qty,
    int? returnedQty,
    ItemCondition? condition,
    String? conditionNote,
    int? fineAmount,
  }) {
    return RentalItemModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      selectedSize: selectedSize ?? this.selectedSize,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      replacementPriceSnapshot: replacementPriceSnapshot ?? this.replacementPriceSnapshot,
      qty: qty ?? this.qty,
      returnedQty: returnedQty ?? this.returnedQty,
      condition: condition ?? this.condition,
      conditionNote: conditionNote ?? this.conditionNote,
      fineAmount: fineAmount ?? this.fineAmount,
    );
  }
}

class CollateralModel {
  final CollateralType type;
  final String note; // e.g. "KTP a.n Dimas - 4 digit: 1234"
  final bool isReturned;
  final DateTime? returnedAt;

  const CollateralModel({
    required this.type,
    required this.note,
    this.isReturned = false,
    this.returnedAt,
  });

  String get typeLabel {
    switch (type) {
      case CollateralType.ktp:
        return 'KTP';
      case CollateralType.sim:
        return 'SIM';
      case CollateralType.ktm:
        return 'KTM';
      case CollateralType.paspor:
        return 'Paspor';
      case CollateralType.lainnya:
        return 'Lainnya';
    }
  }

  CollateralModel copyWith({
    CollateralType? type,
    String? note,
    bool? isReturned,
    DateTime? returnedAt,
  }) {
    return CollateralModel(
      type: type ?? this.type,
      note: note ?? this.note,
      isReturned: isReturned ?? this.isReturned,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }
}

class DepositModel {
  final int amount; // nominal deposit uang
  final int usedAmount; // dipakai bayar tagihan/denda
  final int refundedAmount; // dikembalikan ke pelanggan
  final bool isSettled;

  const DepositModel({
    required this.amount,
    this.usedAmount = 0,
    this.refundedAmount = 0,
    this.isSettled = false,
  });

  DepositModel copyWith({
    int? amount,
    int? usedAmount,
    int? refundedAmount,
    bool? isSettled,
  }) {
    return DepositModel(
      amount: amount ?? this.amount,
      usedAmount: usedAmount ?? this.usedAmount,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

class PaymentRecord {
  final String id;
  final PaymentType type;
  final PaymentMethod method;
  final int amount;
  final DateTime time;
  final String cashierName;

  const PaymentRecord({
    required this.id,
    required this.type,
    required this.method,
    required this.amount,
    required this.time,
    required this.cashierName,
  });
}

class RentalFeeItem {
  final String id;
  final String name; // mis. "Cuci Tenda", "Denda Telat 2 Hari"
  final String type; // "telat", "kotor", "rusak", "hilang"
  final int amount;
  final String note;

  const RentalFeeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.note = '',
  });
}

class RentalModel {
  final String id;
  final String rentalNumber; // RNT-20261016-A-0001
  final CustomerModel customer;
  final String cashierName;
  final DateTime pickupDate;
  final DateTime scheduledReturnDate;
  final DateTime? actualReturnDate;
  final int durationDays;
  final int subtotal;
  final int discount;
  final int totalSewa;
  final int dpPaid;
  final RentalStatus status;
  final List<RentalItemModel> items;
  final CollateralModel? collateral; // null jika menggunakan deposit uang
  final DepositModel? deposit; // null jika menggunakan jaminan identitas
  final List<PaymentRecord> payments;
  final List<RentalFeeItem> fees;
  final String note;

  const RentalModel({
    required this.id,
    required this.rentalNumber,
    required this.customer,
    required this.cashierName,
    required this.pickupDate,
    required this.scheduledReturnDate,
    this.actualReturnDate,
    required this.durationDays,
    required this.subtotal,
    this.discount = 0,
    required this.totalSewa,
    required this.dpPaid,
    this.status = RentalStatus.aktif,
    required this.items,
    this.collateral,
    this.deposit,
    this.payments = const [],
    this.fees = const [],
    this.note = '',
  });

  /// PRD 3.6: Status turunan "Telat" jika belum selesai dan hari ini > scheduledReturnDate
  bool get isOverdue {
    if (status == RentalStatus.selesai || status == RentalStatus.dibatalkan) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final returnDue = DateTime(
      scheduledReturnDate.year,
      scheduledReturnDate.month,
      scheduledReturnDate.day,
    );
    return today.isAfter(returnDue);
  }

  /// Hitung hari terlambat sampai hari ini
  int get overdueDays {
    if (!isOverdue) return 0;
    final now = DateTime.now();
    return RentalCalculationEngine.calculateLateDays(scheduledReturnDate, now);
  }

  /// Sisa sewa yang belum terbayar dari DP
  int get remainingRentalFee {
    final remaining = totalSewa - dpPaid;
    return remaining > 0 ? remaining : 0;
  }

  /// Total denda yang sudah dicatat
  int get totalFees => fees.fold(0, (sum, f) => sum + f.amount);

  /// Total tagihan sisa sewa + denda
  int get totalOutstanding => remainingRentalFee + totalFees;

  RentalModel copyWith({
    String? id,
    String? rentalNumber,
    CustomerModel? customer,
    String? cashierName,
    DateTime? pickupDate,
    DateTime? scheduledReturnDate,
    DateTime? actualReturnDate,
    int? durationDays,
    int? subtotal,
    int? discount,
    int? totalSewa,
    int? dpPaid,
    RentalStatus? status,
    List<RentalItemModel>? items,
    CollateralModel? collateral,
    DepositModel? deposit,
    List<PaymentRecord>? payments,
    List<RentalFeeItem>? fees,
    String? note,
  }) {
    return RentalModel(
      id: id ?? this.id,
      rentalNumber: rentalNumber ?? this.rentalNumber,
      customer: customer ?? this.customer,
      cashierName: cashierName ?? this.cashierName,
      pickupDate: pickupDate ?? this.pickupDate,
      scheduledReturnDate: scheduledReturnDate ?? this.scheduledReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      durationDays: durationDays ?? this.durationDays,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      totalSewa: totalSewa ?? this.totalSewa,
      dpPaid: dpPaid ?? this.dpPaid,
      status: status ?? this.status,
      items: items ?? this.items,
      collateral: collateral ?? this.collateral,
      deposit: deposit ?? this.deposit,
      payments: payments ?? this.payments,
      fees: fees ?? this.fees,
      note: note ?? this.note,
    );
  }
}
