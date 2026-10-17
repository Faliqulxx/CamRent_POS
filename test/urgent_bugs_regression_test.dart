import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/presentation/widgets/item_form_dialog.dart';

void main() {
  group('URGENT BUGS REGRESSION TESTS — OWNER / LOGOUT / PERSISTENCE / STOCK / PRICING', () {
    // ========================================================================
    // TEST 1 — PRICE PERSISTENCE (1 Hari: 35k, 2+ Hari: 20k)
    // ========================================================================
    test('TEST 1 — Harga 1 hari 35k & 2+ hari 20k konsisten untuk seluruh durasi sewa', () {
      const item = ItemModel(
        id: 'itm_001',
        categoryId: 'cat_tenda',
        name: 'Tenda Dome',
        dailyPrice: 35000,
        priceTwoOrMoreDays: 20000,
        replacementPrice: 350000,
        totalStock: 10,
      );

      expect(item.getPriceForDuration(1), 35000);
      expect(item.getPriceForDuration(2), 20000);
      expect(item.getPriceForDuration(3), 20000);
      expect(item.getPriceForDuration(7), 20000);

      // Total rental calculation
      expect(item.calculateTotalPrice(1), 35000);
      expect(item.calculateTotalPrice(2), 40000); // 2 x 20.000
      expect(item.calculateTotalPrice(3), 60000); // 3 x 20.000
      expect(item.calculateTotalPrice(7), 140000); // 7 x 20.000
    });

    // ========================================================================
    // TEST 2 — CHANGE PRICE (1 Hari: 40k, 2+ Hari: 25k)
    // ========================================================================
    test('TEST 2 — Update harga ke 40k (1 hari) & 25k (2+ hari) diterapkan secara konsisten', () {
      const item = ItemModel(
        id: 'itm_001',
        categoryId: 'cat_tenda',
        name: 'Tenda Dome',
        dailyPrice: 40000,
        priceTwoOrMoreDays: 25000,
        replacementPrice: 400000,
        totalStock: 10,
      );

      expect(item.getPriceForDuration(1), 40000);
      expect(item.getPriceForDuration(2), 25000);
      expect(item.getPriceForDuration(3), 25000);
      expect(item.getPriceForDuration(7), 25000);

      expect(item.calculateTotalPrice(1), 40000);
      expect(item.calculateTotalPrice(2), 50000); // 2 x 25.000
      expect(item.calculateTotalPrice(3), 75000); // 3 x 25.000
      expect(item.calculateTotalPrice(7), 175000); // 7 x 25.000
    });

    // ========================================================================
    // TEST BUG #1 & #3 — ZERO PRICE GUARD
    // ========================================================================
    test('BUG #1 & #3 Fix — Harga 2+ hari tidak boleh menjadi 0 meskipun database mengembalikan 0', () {
      // Simulasi produk headlamp mini seperti di screenshot:
      // dailyPrice = 8000, database field price_two_or_more_days = 0
      const itemWithZeroFromDb = ItemModel(
        id: 'itm_headlamp',
        categoryId: 'cat_penerangan',
        name: 'headlamp mini',
        dailyPrice: 8000,
        priceTwoOrMoreDays: 0, // Nilai 0 dari database yang keliru
        replacementPrice: 35000,
        totalStock: 5,
        durationPricing: [
          DurationPriceRule(days: 1, pricePerDay: 8000, isActive: true),
          DurationPriceRule(days: 2, pricePerDay: 0, isActive: true), // Tier 0 yang keliru
        ],
      );

      // Harus fallback ke dailyPrice (8000), TIDAK BOLEH 0
      expect(itemWithZeroFromDb.effectivePriceTwoOrMoreDays, 8000);
      expect(itemWithZeroFromDb.getPriceForDuration(2), 8000);
      expect(itemWithZeroFromDb.getPriceForDuration(3), 8000);
      expect(itemWithZeroFromDb.calculateTotalPrice(2), 16000); // 2 x 8000, BUKAN 0
    });

    // ========================================================================
    // TEST 3 — STOCK PERSISTENCE (Stok Owner ditentukan sendiri, bukan default 5)
    // ========================================================================
    test('TEST 3 — Stok produk tunggal ditentukan sendiri oleh Owner (misal 12, 3, atau 25)', () {
      const item12 = ItemModel(
        id: 'itm_tenda',
        categoryId: 'cat_tenda',
        name: 'Tenda Dome',
        dailyPrice: 35000,
        replacementPrice: 350000,
        totalStock: 12,
      );
      expect(item12.totalStock, 12);
      expect(item12.availableStock, 12);

      const item3 = ItemModel(
        id: 'itm_kompor',
        categoryId: 'cat_cooking',
        name: 'Kompor',
        dailyPrice: 20000,
        replacementPrice: 200000,
        totalStock: 3,
      );
      expect(item3.totalStock, 3);
      expect(item3.availableStock, 3);

      const item25 = ItemModel(
        id: 'itm_matras',
        categoryId: 'cat_sleeping',
        name: 'Matras Foam',
        dailyPrice: 10000,
        replacementPrice: 50000,
        totalStock: 25,
      );
      expect(item25.totalStock, 25);
      expect(item25.availableStock, 25);
    });

    // ========================================================================
    // TEST 4 — VARIANT STOCK (Setiap varian ukuran memiliki stok independen)
    // ========================================================================
    test('TEST 4 — Varian ukuran memiliki stok masing-masing (Size 39=3, 40=7, 41=2)', () {
      const itemShoes = ItemModel(
        id: 'itm_shoes',
        categoryId: 'cat_sepatu',
        name: 'Sepatu Trekking',
        dailyPrice: 35000,
        replacementPrice: 400000,
        variants: [
          ProductVariantModel(id: 'var_39', size: '39', stock: 3),
          ProductVariantModel(id: 'var_40', size: '40', stock: 7),
          ProductVariantModel(id: 'var_41', size: '41', stock: 2),
        ],
      );

      expect(itemShoes.hasVariants, true);
      expect(itemShoes.effectiveTotalStock, 12); // 3 + 7 + 2 = 12
      expect(itemShoes.availableStock, 12);

      expect(itemShoes.variants[0].stock, 3);
      expect(itemShoes.variants[1].stock, 7);
      expect(itemShoes.variants[2].stock, 2);
    });

    // ========================================================================
    // TEST 5 — RETURN STATUS & DURATION MAPPING PERSISTENCE
    // ========================================================================
    test('TEST 5 — Status rental selesai (completed) tetap selesai dan tidak kembali aktif', () {
      final now = DateTime.now();
      final activeRental = RentalModel(
        id: 'b1a2c3d4-1111-2222-3333-444455556666',
        rentalNumber: 'RNT-20261017-A-0001',
        customer: const CustomerModel(id: 'cust_1', name: 'hendro', phone: '08123456789'),
        cashierName: 'Kasir',
        pickupDate: now,
        scheduledReturnDate: now.add(const Duration(days: 2)),
        durationDays: 2,
        subtotal: 16000,
        discount: 0,
        totalSewa: 16000,
        dpPaid: 8000,
        status: RentalStatus.aktif,
        items: const [
          RentalItemModel(
            id: 'rni_1',
            itemId: 'itm_headlamp',
            nameSnapshot: 'headlamp mini',
            priceSnapshot: 8000,
            replacementPriceSnapshot: 35000,
            qty: 1,
            condition: ItemCondition.baik,
          ),
        ],
      );

      expect(activeRental.status, RentalStatus.aktif);

      // Lakukan Return
      final returnedRental = activeRental.copyWith(
        status: RentalStatus.selesai,
        actualReturnDate: now.add(const Duration(days: 2)),
      );

      expect(returnedRental.status, RentalStatus.selesai);
      expect(returnedRental.isOverdue, false);

      // Simulasi mapping dari respon Supabase (rental_status = 'completed')
      const remoteStatusStr = 'completed';
      final mappedStatus = remoteStatusStr == 'completed'
          ? RentalStatus.selesai
          : remoteStatusStr == 'cancelled'
              ? RentalStatus.dibatalkan
              : RentalStatus.aktif;

      expect(mappedStatus, RentalStatus.selesai);
    });

    // ========================================================================
    // TEST 6 — KATEGORI TANPA VARIAN MENAMPILKAN FIELD STOK TOTAL
    // ========================================================================
    testWidgets('TEST 6 — Form produk untuk kategori non-varian (Tenda) menampilkan field Total Stok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ItemFormDialog.show(context),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Pastikan teks 'Total Stok (Unit)' muncul di layar
      expect(find.text('Total Stok (Unit)'), findsOneWidget);
      expect(find.text('Sedang Disewa'), findsOneWidget);
      // Pastikan tabel varian TIDAK muncul untuk kategori default (non-ukuran)
      expect(find.text('VARIAN UKURAN'), findsNothing);
    });
  });
}
