import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/domain/calculator.dart';

void main() {
  group('PRD Section 9: Acceptance Criteria Unit Tests', () {
    test('Ambil 10 Okt, kembali 12 Okt, 1 item Rp 50.000/hari, qty 1 -> 2 hari, total Rp 100.000, DP 50% = Rp 50.000', () {
      final pickup = DateTime(2026, 10, 10);
      final returnDate = DateTime(2026, 10, 12);

      final days = RentalCalculationEngine.calculateDuration(pickup, returnDate);
      expect(days, 2);

      final itemSubtotal = RentalCalculationEngine.calculateItemSubtotal(
        dailyPrice: 50000,
        qty: 1,
        durationDays: days,
      );
      expect(itemSubtotal, 100000);

      final totals = RentalCalculationEngine.calculateTotals(
        itemsSubtotal: itemSubtotal,
        discount: 0,
        minDpPercentage: 50,
      );
      expect(totals.totalSewa, 100000);
      expect(totals.minDp, 50000);
      expect(totals.sisaSewa, 50000);
    });

    test('Ambil dan kembali di tanggal sama -> 1 hari', () {
      final date = DateTime(2026, 10, 10);
      final days = RentalCalculationEngine.calculateDuration(date, date);
      expect(days, 1);
    });

    test('Kembali 1 tanggal setelah jatuh tempo (jam berapa pun) -> Telat 1 hari', () {
      final scheduled = DateTime(2026, 10, 12, 10, 0);
      final actual = DateTime(2026, 10, 13, 20, 0);

      final lateDays = RentalCalculationEngine.calculateLateDays(scheduled, actual);
      expect(lateDays, 1);
    });

    test('Toleransi 1 hari, terlambat 1 hari -> Denda Rp 0', () {
      final scheduled = DateTime(2026, 10, 12);
      final actual = DateTime(2026, 10, 13);

      final lateDays = RentalCalculationEngine.calculateLateDays(
        scheduled,
        actual,
        gracePeriodDays: 1,
      );
      expect(lateDays, 0);

      final fee = RentalCalculationEngine.calculateLateFeeForItem(
        dailyPrice: 50000,
        qty: 1,
        lateDays: lateDays,
      );
      expect(fee, 0);
    });

    test('Denda telat persen 100%, 2 item, hanya 1 item telat -> Denda hanya dari item yang telat', () {
      const lateDaysItem1 = 0;
      const lateDaysItem2 = 2;

      final feeItem1 = RentalCalculationEngine.calculateLateFeeForItem(
        dailyPrice: 50000,
        qty: 1,
        lateDays: lateDaysItem1,
      );
      final feeItem2 = RentalCalculationEngine.calculateLateFeeForItem(
        dailyPrice: 35000,
        qty: 1,
        lateDays: lateDaysItem2,
        ratePercent: 1.0,
      );

      expect(feeItem1, 0);
      expect(feeItem2, 70000); // 35.000 x 2 hari
    });

    test('Deposit Rp 100.000, tagihan Rp 40.000 -> Kembalian deposit Rp 60.000', () {
      final settlement = RentalCalculationEngine.calculateSettlement(
        remainingRentalFee: 20000,
        totalFines: 20000,
        depositAmount: 100000,
      );

      expect(settlement.totalBill, 40000);
      expect(settlement.depositUsed, 40000);
      expect(settlement.remainingToPay, 0);
      expect(settlement.depositRefund, 60000);
    });

    test('Deposit Rp 50.000, tagihan Rp 80.000 -> Sisa bayar Rp 30.000', () {
      final settlement = RentalCalculationEngine.calculateSettlement(
        remainingRentalFee: 50000,
        totalFines: 30000,
        depositAmount: 50000,
      );

      expect(settlement.totalBill, 80000);
      expect(settlement.depositUsed, 50000);
      expect(settlement.remainingToPay, 30000);
      expect(settlement.depositRefund, 0);
    });
  });
}
