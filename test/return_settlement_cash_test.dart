import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/domain/calculator.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() {
  group('Perhitungan Uang Tunai & Kembalian Pelunasan Pengembalian Alat', () {
    test('1. Uang tunai diterima lebih besar -> Kembalian positif', () {
      const remainingToPay = 75000;
      const cashPaid = 100000;
      const change = cashPaid - remainingToPay;

      expect(change, 25000);
      expect(change >= 0, isTrue);
    });

    test('2. Uang pas -> Kembalian Rp 0', () {
      const remainingToPay = 75000;
      const cashPaid = 75000;
      const change = cashPaid - remainingToPay;

      expect(change, 0);
      expect(change >= 0, isTrue);
    });

    test('3. Uang tunai diterima kurang -> Terdeteksi kurang bayar', () {
      const remainingToPay = 75000;
      const cashPaid = 50000;
      const diff = cashPaid - remainingToPay;

      expect(diff, -25000);
      expect(diff < 0, isTrue);
    });

    test('4. Process return settlement mencatat penerimaan pelunasan ke shift kasir aktif', () {
      final notifier = AppStateNotifier();
      notifier.setRole(AppRole.kasir);
      notifier.openShift(200000);

      final activeRental = notifier.state.rentals.first;
      final settlement = RentalCalculationEngine.calculateSettlement(
        remainingRentalFee: 75000,
        totalFines: 0,
        depositAmount: 0,
      );

      final initialCashInShift = notifier.state.activeCashierShift!.totalCashPayments;

      notifier.processReturnSettlement(
        rentalId: activeRental.id,
        updatedItems: activeRental.items,
        appliedFees: const [],
        settlement: settlement,
        paymentMethod: PaymentMethod.tunai,
        returnCollateralPhysical: true,
      );

      // Tunai pada shift aktif bertambah sesuai tagihan yang dibayarkan
      expect(
        notifier.state.activeCashierShift!.totalCashPayments,
        initialCashInShift + settlement.remainingToPay,
      );
    });
  });
}
