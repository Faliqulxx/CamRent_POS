import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() {
  group('Owner Audit & System Hardening Unit Tests', () {
    late AppStateNotifier notifier;

    setUp(() {
      notifier = AppStateNotifier();
    });

    test('1. Owner dapat mengupdate pengaturan toko dan nilai tersimpan di state', () async {
      final newSettings = const StoreSettingsModel(
        storeName: 'CampRent Gunung Kidul',
        storePhone: '081234567890',
        storeAddress: 'Jl. Baron KM 5, Wonosari',
        minDpPercent: 40,
        lateGracePeriodDays: 1,
        defaultDepositAmount: 75000,
        minDepositAmount: 25000,
      );

      await notifier.updateStoreSettings(newSettings, lateFeePerDay: 30000);

      expect(notifier.state.settings.storeName, 'CampRent Gunung Kidul');
      expect(notifier.state.settings.storePhone, '081234567890');
      expect(notifier.state.settings.minDpPercent, 40);
      expect(notifier.state.settings.lateGracePeriodDays, 1);
      expect(notifier.state.settings.defaultDepositAmount, 75000);
    });

    test('2. Pembatalan Transaksi (Cancel Rental) mengembalikan stok alat yang disewa', () {
      final item = const ItemModel(
        id: 'item_tenda_dome',
        name: 'Tenda Dome 4P',
        categoryId: 'cat_tenda',
        dailyPrice: 50000,
        replacementPrice: 500000,
        totalStock: 5,
        rentedStock: 2,
        damagedStock: 0,
      );

      final customer = const CustomerModel(
        id: 'cust_01',
        name: 'Andi Pendaki',
        phone: '0811223344',
      );

      final rental = RentalModel(
        id: 'rnt_test_cancel',
        rentalNumber: 'RNT-2026-001',
        customer: customer,
        cashierName: 'Owner CampRent',
        pickupDate: DateTime.now(),
        scheduledReturnDate: DateTime.now().add(const Duration(days: 2)),
        durationDays: 2,
        subtotal: 200000,
        discount: 0,
        totalSewa: 200000,
        dpPaid: 100000,
        status: RentalStatus.aktif,
        items: [
          const RentalItemModel(
            id: 'ri_01',
            itemId: 'item_tenda_dome',
            nameSnapshot: 'Tenda Dome 4P',
            priceSnapshot: 50000,
            replacementPriceSnapshot: 500000,
            qty: 2,
          ),
        ],
      );

      notifier.state = notifier.state.copyWith(
        items: [item],
        customers: [customer],
        rentals: [rental],
      );

      expect(notifier.state.items.first.rentedStock, 2);
      expect(notifier.state.items.first.availableStock, 3);

      // Batalkan transaksi
      final success = notifier.cancelRental(rental.id);
      expect(success, isTrue);

      // Stok rental kembali menjadi 0, available stock kembali menjadi 5
      expect(notifier.state.items.first.rentedStock, 0);
      expect(notifier.state.items.first.availableStock, 5);

      // Status rental berubah menjadi dibatalkan
      expect(notifier.state.rentals.first.status, RentalStatus.dibatalkan);

      // Membatalkan transaksi yang sudah dibatalkan tidak boleh mengembalikan stok dua kali
      final doubleCancel = notifier.cancelRental(rental.id);
      expect(doubleCancel, isFalse);
      expect(notifier.state.items.first.rentedStock, 0);
      expect(notifier.state.items.first.availableStock, 5);
    });

    test('3. Proteksi Hapus Pelanggan: Tidak boleh dihapus jika memiliki rental aktif', () {
      final customer = const CustomerModel(
        id: 'cust_active',
        name: 'Rudi Petualang',
        phone: '0899887766',
      );

      final rental = RentalModel(
        id: 'rnt_active_01',
        rentalNumber: 'RNT-2026-002',
        customer: customer,
        cashierName: 'Owner CampRent',
        pickupDate: DateTime.now(),
        scheduledReturnDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 1,
        subtotal: 50000,
        discount: 0,
        totalSewa: 50000,
        dpPaid: 50000,
        status: RentalStatus.aktif,
        items: const [],
      );

      notifier.state = notifier.state.copyWith(
        customers: [customer],
        rentals: [rental],
      );

      // Coba hapus pelanggan yang sedang memiliki rental aktif
      final deleted = notifier.deleteCustomer(customer.id);
      expect(deleted, isFalse);
      expect(notifier.state.customers.any((c) => c.id == customer.id), isTrue);

      // Setelah rental selesai, pelanggan baru bisa dihapus
      notifier.state = notifier.state.copyWith(
        rentals: [rental.copyWith(status: RentalStatus.selesai)],
      );

      final deletedSuccess = notifier.deleteCustomer(customer.id);
      expect(deletedSuccess, isTrue);
      expect(notifier.state.customers.any((c) => c.id == customer.id), isFalse);
    });

    test('4. Toggle Customer Blacklist memperbarui status pelanggan secara konsisten', () {
      final customer = const CustomerModel(
        id: 'cust_blacklist_test',
        name: 'Oknum Rusak Alat',
        phone: '0822334455',
        isBlacklisted: false,
      );

      notifier.state = notifier.state.copyWith(
        customers: [customer],
      );

      // Blacklist customer
      notifier.toggleCustomerBlacklist(customer.id, reason: 'Alat tidak dikembalikan tepat waktu');
      expect(notifier.state.customers.first.isBlacklisted, isTrue);
      expect(notifier.state.customers.first.blacklistReason, 'Alat tidak dikembalikan tepat waktu');

      // Unblacklist customer
      notifier.toggleCustomerBlacklist(customer.id);
      expect(notifier.state.customers.first.isBlacklisted, isFalse);
      expect(notifier.state.customers.first.blacklistReason, isNull);
    });

    test('5. Proteksi Hapus Produk: Tidak boleh dihapus jika sedang dalam transaksi aktif', () {
      final item = const ItemModel(
        id: 'item_carrier_60l',
        name: 'Carrier 60L Eiger',
        categoryId: 'cat_carrier',
        dailyPrice: 40000,
        replacementPrice: 800000,
        totalStock: 3,
        rentedStock: 1,
      );

      final customer = const CustomerModel(id: 'c1', name: 'Budi', phone: '0812');
      final rental = RentalModel(
        id: 'r1',
        rentalNumber: 'RNT-001',
        customer: customer,
        cashierName: 'Owner',
        pickupDate: DateTime.now(),
        scheduledReturnDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 1,
        subtotal: 40000,
        discount: 0,
        totalSewa: 40000,
        dpPaid: 40000,
        status: RentalStatus.aktif,
        items: [
          const RentalItemModel(
            id: 'ri1',
            itemId: 'item_carrier_60l',
            nameSnapshot: 'Carrier 60L Eiger',
            priceSnapshot: 40000,
            replacementPriceSnapshot: 800000,
            qty: 1,
          ),
        ],
      );

      notifier.state = notifier.state.copyWith(
        items: [item],
        rentals: [rental],
      );

      // Coba hapus item yang sedang aktif disewa
      final deleteResult = notifier.deleteItem(item.id);
      expect(deleteResult, isFalse);
      expect(notifier.state.items.any((it) => it.id == item.id), isTrue);

      // Selesaikan transaksi rental
      notifier.state = notifier.state.copyWith(
        rentals: [rental.copyWith(status: RentalStatus.selesai)],
      );

      // Hapus produk setelah rental selesai
      final deleteSuccess = notifier.deleteItem(item.id);
      expect(deleteSuccess, isTrue);
      expect(notifier.state.items.any((it) => it.id == item.id), isFalse);
    });
  });
}
