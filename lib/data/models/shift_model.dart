enum ShiftStatus {
  sedangBerjalan,
  selesai,
  belumBuka,
}

enum CashDifferenceStatus {
  sesuai,
  lebih,
  kurang,
}

class CashierShiftModel {
  final String id;
  final String cashierId;
  final String cashierName;
  final String cashierEmail;
  final DateTime date;
  final DateTime startTime;
  final DateTime? endTime;
  final int initialCash; // Modal awal kas
  final int totalTransactions; // Jumlah transaksi
  final int totalCashPayments; // Penerimaan tunai
  final int totalTransferPayments; // Penerimaan transfer
  final int totalQrisPayments; // Penerimaan QRIS
  final int cashExpenses; // Pengeluaran kas tercatat
  final int? actualCash; // Kas aktual hasil penghitungan kasir
  final String? discrepancyNote; // Catatan selisih kasir
  final ShiftStatus status;

  const CashierShiftModel({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.cashierEmail,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.initialCash,
    this.totalTransactions = 0,
    this.totalCashPayments = 0,
    this.totalTransferPayments = 0,
    this.totalQrisPayments = 0,
    this.cashExpenses = 0,
    this.actualCash,
    this.discrepancyNote,
    this.status = ShiftStatus.sedangBerjalan,
  });

  int get totalIncome => totalCashPayments + totalTransferPayments + totalQrisPayments;

  // Kas yang seharusnya ada di laci: Modal Awal + Tunai Masuk - Pengeluaran Kas
  int get expectedCash => initialCash + totalCashPayments - cashExpenses;

  // Selisih kas: Aktual - Diharapkan
  int? get cashDifference => actualCash != null ? (actualCash! - expectedCash) : null;

  CashDifferenceStatus? get differenceStatus {
    if (actualCash == null) return null;
    final diff = cashDifference!;
    if (diff == 0) return CashDifferenceStatus.sesuai;
    if (diff > 0) return CashDifferenceStatus.lebih;
    return CashDifferenceStatus.kurang;
  }

  String get statusLabel {
    switch (status) {
      case ShiftStatus.sedangBerjalan:
        return 'Sedang Berjalan';
      case ShiftStatus.selesai:
        return 'Selesai';
      case ShiftStatus.belumBuka:
        return 'Belum Buka Shift';
    }
  }

  String get differenceLabel {
    final ds = differenceStatus;
    if (ds == null) return '-';
    switch (ds) {
      case CashDifferenceStatus.sesuai:
        return 'Kas Sesuai';
      case CashDifferenceStatus.lebih:
        return 'Kas Lebih';
      case CashDifferenceStatus.kurang:
        return 'Kas Kurang';
    }
  }

  CashierShiftModel copyWith({
    String? id,
    String? cashierId,
    String? cashierName,
    String? cashierEmail,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    int? initialCash,
    int? totalTransactions,
    int? totalCashPayments,
    int? totalTransferPayments,
    int? totalQrisPayments,
    int? cashExpenses,
    int? actualCash,
    String? discrepancyNote,
    ShiftStatus? status,
  }) {
    return CashierShiftModel(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      cashierEmail: cashierEmail ?? this.cashierEmail,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      initialCash: initialCash ?? this.initialCash,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalCashPayments: totalCashPayments ?? this.totalCashPayments,
      totalTransferPayments: totalTransferPayments ?? this.totalTransferPayments,
      totalQrisPayments: totalQrisPayments ?? this.totalQrisPayments,
      cashExpenses: cashExpenses ?? this.cashExpenses,
      actualCash: actualCash ?? this.actualCash,
      discrepancyNote: discrepancyNote ?? this.discrepancyNote,
      status: status ?? this.status,
    );
  }
}
