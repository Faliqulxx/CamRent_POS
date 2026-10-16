/// Pure business logic calculation engine for CampRent POS.
/// Free of Flutter UI dependencies, adheres strictly to PRD section 3 and 9.
library;

class RentalCalculationEngine {
  /// 3.1 Durasi Sewa
  /// `jumlah_hari = tanggal_kembali - tanggal_ambil`, minimal 1 hari.
  /// Jika [includePickupDay] aktif: `selisih + 1`.
  static int calculateDuration(
    DateTime pickupDate,
    DateTime returnDate, {
    bool includePickupDay = false,
  }) {
    final pickup = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
    final ret = DateTime(returnDate.year, returnDate.month, returnDate.day);

    final diff = ret.difference(pickup).inDays;
    if (includePickupDay) {
      final days = diff + 1;
      return days < 1 ? 1 : days;
    }

    if (diff <= 0) {
      return 1; // Ambil dan kembali di tanggal sama = 1 hari minimal
    }
    return diff;
  }

  /// 3.1 Hitung subtotal item
  /// `subtotal_item = harga_per_hari x qty x jumlah_hari`
  static int calculateItemSubtotal({
    required int dailyPrice,
    required int qty,
    required int durationDays,
  }) {
    return dailyPrice * qty * durationDays;
  }

  /// 3.1 & 3.2 Total sewa, DP minimum, dan sisa sewa
  static RentalTotals calculateTotals({
    required int itemsSubtotal,
    int discount = 0,
    int minDpPercentage = 50,
  }) {
    final totalAfterDiscount = (itemsSubtotal - discount).clamp(0, 999999999);
    // DP dihitung dari total sewa setelah diskon
    final minDp = ((totalAfterDiscount * minDpPercentage) / 100).ceil();
    return RentalTotals(
      subtotal: itemsSubtotal,
      discount: discount,
      totalSewa: totalAfterDiscount,
      minDp: minDp,
      sisaSewa: totalAfterDiscount - minDp,
    );
  }

  /// 3.4 Hitung hari telat
  /// Setiap tanggal setelah jatuh tempo = 1 hari telat, apa pun jamnya.
  static int calculateLateDays(
    DateTime scheduledReturnDate,
    DateTime actualReturnDate, {
    int gracePeriodDays = 0,
  }) {
    final scheduled = DateTime(
      scheduledReturnDate.year,
      scheduledReturnDate.month,
      scheduledReturnDate.day,
    );
    final actual = DateTime(
      actualReturnDate.year,
      actualReturnDate.month,
      actualReturnDate.day,
    );

    final diff = actual.difference(scheduled).inDays;
    if (diff <= 0) return 0;

    final lateAfterGrace = diff - gracePeriodDays;
    return lateAfterGrace > 0 ? lateAfterGrace : 0;
  }

  /// 3.4 Hitung denda telat per item
  /// Default: persen dari harga sewa per hari (mis. 100% = 1.0) x hari telat x qty
  static int calculateLateFeeForItem({
    required int dailyPrice,
    required int qty,
    required int lateDays,
    double ratePercent = 1.0, // 100%
  }) {
    if (lateDays <= 0 || qty <= 0) return 0;
    return ((dailyPrice * ratePercent) * lateDays * qty).round();
  }

  /// 3.5 Penyelesaian saat pengembalian
  /// total_tagihan = sisa_pelunasan_sewa + total_denda
  /// deposit_dipakai = min(deposit_uang, total_tagihan)
  /// sisa_bayar      = total_tagihan - deposit_dipakai       (dibayar pelanggan)
  /// kembalian_dep   = deposit_uang - deposit_dipakai         (dikembalikan ke pelanggan)
  static SettlementSummary calculateSettlement({
    required int remainingRentalFee, // sisa pelunasan sewa yang belum dibayar
    required int totalFines, // total denda (telat + kotor + rusak + hilang)
    required int depositAmount, // deposit uang yang dipegang toko
  }) {
    final totalBill = remainingRentalFee + totalFines;
    final depositUsed = depositAmount < totalBill ? depositAmount : totalBill;
    final remainingToPay = totalBill - depositUsed;
    final depositRefund = depositAmount - depositUsed;

    return SettlementSummary(
      totalBill: totalBill,
      depositUsed: depositUsed,
      remainingToPay: remainingToPay,
      depositRefund: depositRefund,
    );
  }
}

class RentalTotals {
  final int subtotal;
  final int discount;
  final int totalSewa;
  final int minDp;
  final int sisaSewa;

  const RentalTotals({
    required this.subtotal,
    required this.discount,
    required this.totalSewa,
    required this.minDp,
    required this.sisaSewa,
  });
}

class SettlementSummary {
  final int totalBill;
  final int depositUsed;
  final int remainingToPay;
  final int depositRefund;

  const SettlementSummary({
    required this.totalBill,
    required this.depositUsed,
    required this.remainingToPay,
    required this.depositRefund,
  });
}
