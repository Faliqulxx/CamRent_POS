import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() {
  group('Stock Breakdown & Tiered Duration Pricing Tests', () {
    test('Barang A with total stock 12 and 6 rented has 6 available stock', () {
      const itemA = ItemModel(
        id: 'item_a',
        categoryId: 'cat_tenda',
        name: 'Tenda Dome 4P',
        dailyPrice: 35000,
        replacementPrice: 350000,
        totalStock: 12,
        rentedStock: 6,
        damagedStock: 0,
      );

      expect(itemA.effectiveTotalStock, 12);
      expect(itemA.effectiveRentedStock, 6);
      expect(itemA.availableStock, 6);
      expect(itemA.isOutOfStock, isFalse);
    });

    test('2-Tier Duration Pricing: 1 day 35k, 2+ days 20k/day for any duration >= 2', () {
      const item = ItemModel(
        id: 'tenda_promo',
        categoryId: 'cat_tenda',
        name: 'Tenda Camping Arpenaz',
        dailyPrice: 35000,
        priceTwoOrMoreDays: 20000,
        replacementPrice: 400000,
        totalStock: 10,
      );

      // Sewa 1 hari -> 1 * 35.000 = 35.000
      expect(item.getPriceForDuration(1), 35000);
      expect(item.calculateTotalPrice(1), 35000);

      // Sewa 2 hari -> 2 * 20.000 = 40.000
      expect(item.getPriceForDuration(2), 20000);
      expect(item.calculateTotalPrice(2), 40000);

      // Sewa 3 hari -> 3 * 20.000 = 60.000
      expect(item.getPriceForDuration(3), 20000);
      expect(item.calculateTotalPrice(3), 60000);

      // Sewa 5 hari -> 5 * 20.000 = 100.000
      expect(item.getPriceForDuration(5), 20000);
      expect(item.calculateTotalPrice(5), 100000);

      // Sewa 7 hari -> 7 * 20.000 = 140.000
      expect(item.getPriceForDuration(7), 20000);
      expect(item.calculateTotalPrice(7), 140000);

      // Sewa 30 hari -> 30 * 20.000 = 600.000
      expect(item.getPriceForDuration(30), 20000);
      expect(item.calculateTotalPrice(30), 600000);
    });

    test('Owner changes 1-day to 40k and 2+-day to 25k', () {
      const item = ItemModel(
        id: 'tenda_custom',
        categoryId: 'cat_tenda',
        name: 'Tenda Custom Price',
        dailyPrice: 40000,
        priceTwoOrMoreDays: 25000,
        replacementPrice: 400000,
        totalStock: 5,
      );

      expect(item.calculateTotalPrice(1), 40000);
      expect(item.calculateTotalPrice(2), 50000);
      expect(item.calculateTotalPrice(3), 75000);
      expect(item.calculateTotalPrice(4), 100000);
      expect(item.calculateTotalPrice(7), 175000);
    });

    test('POS calculation applies 2-tier duration pricing to subtotal', () {
      const item = ItemModel(
        id: 'tenda_promo',
        categoryId: 'cat_tenda',
        name: 'Tenda Camping Arpenaz',
        dailyPrice: 35000,
        priceTwoOrMoreDays: 20000,
        replacementPrice: 400000,
        totalStock: 10,
      );

      final now = DateTime(2026, 10, 17, 10, 0);

      // 1 Hari: 17 Okt ke 18 Okt (1 hari)
      final form1Day = NewRentalFormState(
        selectedCustomer: const CustomerModel(id: 'c1', name: 'Budi', phone: '0812345'),
        pickupDate: now,
        returnDate: now.add(const Duration(days: 1)),
        cartItems: [
          const CartItem(item: item, qty: 1),
        ],
      );

      expect(form1Day.durationDays, 1);
      // 1 hari * Rp 35.000 * 1 unit = Rp 35.000
      expect(form1Day.itemsSubtotal, 35000);

      // 2 Hari: 17 Okt ke 19 Okt (2 hari)
      final form2Days = NewRentalFormState(
        selectedCustomer: const CustomerModel(id: 'c1', name: 'Budi', phone: '0812345'),
        pickupDate: now,
        returnDate: now.add(const Duration(days: 2)),
        cartItems: [
          const CartItem(item: item, qty: 1),
        ],
      );

      expect(form2Days.durationDays, 2);
      // 2 hari * Rp 20.000 * 1 unit = Rp 40.000
      expect(form2Days.itemsSubtotal, 40000);

      // 7 Hari: 17 Okt ke 24 Okt (7 hari)
      final form7Days = NewRentalFormState(
        selectedCustomer: const CustomerModel(id: 'c1', name: 'Budi', phone: '0812345'),
        pickupDate: now,
        returnDate: now.add(const Duration(days: 7)),
        cartItems: [
          const CartItem(item: item, qty: 1),
        ],
      );

      expect(form7Days.durationDays, 7);
      // 7 hari * Rp 20.000 * 1 unit = Rp 140.000
      expect(form7Days.itemsSubtotal, 140000);
    });

    test('Backward compatibility: ItemModel with legacy durationPricing extracts 2+ days price', () {
      const item = ItemModel(
        id: 'tenda_legacy',
        categoryId: 'cat_tenda',
        name: 'Tenda Legacy',
        dailyPrice: 35000,
        replacementPrice: 400000,
        totalStock: 5,
        durationPricing: [
          DurationPriceRule(days: 2, pricePerDay: 20000, isActive: true),
          DurationPriceRule(days: 7, pricePerDay: 15000, isActive: true),
        ],
      );

      // effectivePriceTwoOrMoreDays mengarah ke tier 2 hari (20.000)
      expect(item.effectivePriceTwoOrMoreDays, 20000);
      expect(item.getPriceForDuration(1), 35000);
      expect(item.getPriceForDuration(2), 20000);
      expect(item.getPriceForDuration(3), 20000);
      expect(item.getPriceForDuration(7), 20000);
      expect(item.calculateTotalPrice(7), 140000);
    });

    test('Return rented stock restores available stock (12 total, 6 rented -> 6 returned = 12 available)', () {
      final notifier = AppStateNotifier();

      const itemTest = ItemModel(
        id: 'item_return_test',
        categoryId: 'cat_tenda',
        name: 'Tenda Dome 4P Return Test',
        dailyPrice: 35000,
        replacementPrice: 350000,
        totalStock: 12,
        rentedStock: 6,
        damagedStock: 0,
      );

      notifier.addItem(itemTest);
      var it = notifier.state.items.firstWhere((i) => i.id == 'item_return_test');
      expect(it.effectiveTotalStock, 12);
      expect(it.effectiveRentedStock, 6);
      expect(it.availableStock, 6);

      // Kembalikan 2 unit secara manual
      notifier.returnRentedStockManually(itemId: 'item_return_test', returnQty: 2);
      it = notifier.state.items.firstWhere((i) => i.id == 'item_return_test');
      expect(it.effectiveRentedStock, 4);
      expect(it.availableStock, 8);

      // Kembalikan sisa 4 unit secara manual
      notifier.returnRentedStockManually(itemId: 'item_return_test', returnQty: 4);
      it = notifier.state.items.firstWhere((i) => i.id == 'item_return_test');
      expect(it.effectiveRentedStock, 0);
      expect(it.availableStock, 12);
    });

    test('Return rented stock on product with size variants restores variant available stock', () {
      final notifier = AppStateNotifier();

      const itemVariantTest = ItemModel(
        id: 'sepatu_return_test',
        categoryId: 'cat_sepatu',
        name: 'Sepatu Trekking Return Test',
        dailyPrice: 25000,
        replacementPrice: 300000,
        variants: [
          ProductVariantModel(id: 'var_40', size: '40', stock: 4, rentedStock: 2),
          ProductVariantModel(id: 'var_41', size: '41', stock: 3, rentedStock: 1),
        ],
      );

      notifier.addItem(itemVariantTest);
      var it = notifier.state.items.firstWhere((i) => i.id == 'sepatu_return_test');
      expect(it.effectiveTotalStock, 7);
      expect(it.effectiveRentedStock, 3);
      expect(it.availableStock, 4);

      // Kembalikan 2 unit ukuran 40
      notifier.returnRentedStockManually(itemId: 'sepatu_return_test', returnQty: 2, variantSize: '40');
      it = notifier.state.items.firstWhere((i) => i.id == 'sepatu_return_test');
      final v40 = it.variants.firstWhere((v) => v.size == '40');
      expect(v40.rentedStock, 0);
      expect(v40.availableStock, 4);

      // Total produk sekarang: 1 disewa (ukuran 41), 6 tersedia
      expect(it.effectiveRentedStock, 1);
      expect(it.availableStock, 6);
    });
  });
}
