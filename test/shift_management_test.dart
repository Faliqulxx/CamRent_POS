import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() {
  group('Ketentuan Final Manajemen Shift Kasir — Unit Tests', () {
    test('1. Kasir wajib membuka shift sebelum dapat bertransaksi', () {
      final notifier = AppStateNotifier();
      notifier.setRole(AppRole.kasir);

      // Awalnya kasir belum membuka shift
      expect(notifier.state.currentRole, AppRole.kasir);
      expect(notifier.state.activeCashierShift, isNull);

      // Kasir membuka shift dengan modal awal Rp 200.000
      notifier.openShift(200000);

      expect(notifier.state.activeCashierShift, isNotNull);
      expect(notifier.state.activeCashierShift!.initialCash, 200000);
      expect(notifier.state.activeCashierShift!.status, ShiftStatus.sedangBerjalan);
      expect(notifier.state.activeCashierShift!.cashierName, contains('Budi Santoso'));

      // Shift aktif juga tercatat di daftar shifts
      final hasActiveInList = notifier.state.shifts.any(
        (s) => s.id == notifier.state.activeCashierShift!.id && s.status == ShiftStatus.sedangBerjalan,
      );
      expect(hasActiveInList, isTrue);
    });

    test('2. Owner tidak wajib membuka shift dan dapat mengakses seluruh menu', () {
      final notifier = AppStateNotifier();
      notifier.setRole(AppRole.admin);

      expect(notifier.state.currentRole, AppRole.admin);
      // Owner tidak memerlukan modal awal dan tidak dibatasi oleh activeCashierShift
      expect(notifier.state.activeCashierShift, isNull);
    });

    test('3. Rekonsiliasi Kas: Kas Sesuai (Selisih Rp 0)', () {
      final shift = CashierShiftModel(
        id: 'test_shf_01',
        cashierId: 'cashier_001',
        cashierName: 'Budi Santoso',
        cashierEmail: 'budi@camprent.com',
        date: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 6)),
        initialCash: 200000,
        totalTransactions: 4,
        totalCashPayments: 350000,
        cashExpenses: 15000,
        actualCash: 535000, // 200k + 350k - 15k = 535k
        status: ShiftStatus.selesai,
      );

      expect(shift.expectedCash, 535000);
      expect(shift.cashDifference, 0);
      expect(shift.differenceStatus, CashDifferenceStatus.sesuai);
      expect(shift.differenceLabel, 'Kas Sesuai');
    });

    test('4. Rekonsiliasi Kas: Kas Lebih (Selisih positif)', () {
      final shift = CashierShiftModel(
        id: 'test_shf_02',
        cashierId: 'cashier_002',
        cashierName: 'Siti Amelia',
        cashierEmail: 'siti@camprent.com',
        date: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 5)),
        initialCash: 150000,
        totalTransactions: 5,
        totalCashPayments: 400000,
        cashExpenses: 0,
        actualCash: 565000, // 150k + 400k = 550k -> Aktual 565k (Lebih 15k)
        discrepancyNote: 'Kelebihan uang receh pelanggan',
        status: ShiftStatus.selesai,
      );

      expect(shift.expectedCash, 550000);
      expect(shift.cashDifference, 15000);
      expect(shift.differenceStatus, CashDifferenceStatus.lebih);
      expect(shift.differenceLabel, 'Kas Lebih');
      expect(shift.discrepancyNote, isNotNull);
    });

    test('5. Rekonsiliasi Kas: Kas Kurang (Selisih negatif)', () {
      final shift = CashierShiftModel(
        id: 'test_shf_03',
        cashierId: 'cashier_001',
        cashierName: 'Budi Santoso',
        cashierEmail: 'budi@camprent.com',
        date: DateTime.now(),
        startTime: DateTime.now().subtract(const Duration(hours: 7)),
        initialCash: 200000,
        totalTransactions: 3,
        totalCashPayments: 300000,
        cashExpenses: 0,
        actualCash: 490000, // 200k + 300k = 500k -> Aktual 490k (Kurang 10k)
        discrepancyNote: 'Salah memberikan kembalian uang pecahan 10rb',
        status: ShiftStatus.selesai,
      );

      expect(shift.expectedCash, 500000);
      expect(shift.cashDifference, -10000);
      expect(shift.differenceStatus, CashDifferenceStatus.kurang);
      expect(shift.differenceLabel, 'Kas Kurang');
      expect(shift.discrepancyNote, isNotNull);
    });

    test('6. Tutup shift: Kasir tidak dapat bertransaksi kembali sampai membuka shift baru', () {
      final notifier = AppStateNotifier();
      notifier.setRole(AppRole.kasir);

      // Buka shift
      notifier.openShift(200000);
      expect(notifier.state.activeCashierShift, isNotNull);
      final shiftId = notifier.state.activeCashierShift!.id;

      // Tutup shift
      notifier.closeShift(
        actualCash: 200000,
        discrepancyNote: null,
      );

      // Setelah ditutup, activeCashierShift menjadi null
      expect(notifier.state.activeCashierShift, isNull);

      // Shift yang ditutup berstatus selesai di riwayat
      final closedShift = notifier.state.shifts.firstWhere((s) => s.id == shiftId);
      expect(closedShift.status, ShiftStatus.selesai);
      expect(closedShift.actualCash, 200000);
      expect(closedShift.endTime, isNotNull);
    });
  });
}
