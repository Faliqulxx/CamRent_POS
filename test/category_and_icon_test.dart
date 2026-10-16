import 'package:flutter_test/flutter_test.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/data/models/item_model.dart';

void main() {
  group('Product Catalog, Category & Size Variant Tests', () {
    late AppStateNotifier notifier;

    setUp(() {
      notifier = AppStateNotifier();
      // Login as Owner (admin) by default for tests
      notifier.quickLogin(AppRole.admin);
    });

    test('Add new category with requiresSize flag updates categories list', () {
      final initialCount = notifier.state.categories.length;

      notifier.addCategory(name: 'Sepatu Outdoor Baru', requiresSize: true);

      expect(notifier.state.categories.length, initialCount + 1);
      final added = notifier.state.categories.last;
      expect(added.name, 'Sepatu Outdoor Baru');
      expect(added.requiresSize, isTrue);
      expect(added.id.startsWith('cat_'), isTrue);
    });

    test('Non-Owner role (Kasir) cannot add or delete category', () {
      notifier.quickLogin(AppRole.kasir);

      expect(
        () => notifier.addCategory(name: 'Kategori Kasir', requiresSize: false),
        throwsA(isA<StateError>()),
      );

      expect(
        () => notifier.deleteCategory('cat_sepatu'),
        throwsA(isA<StateError>()),
      );
    });

    test('Cannot delete default cat_all category', () {
      final success = notifier.deleteCategory('cat_all');
      expect(success, isFalse);
      expect(notifier.state.categories.any((c) => c.id == 'cat_all'), isTrue);
    });

    test('Delete custom category removes it and resets selected category if active', () {
      notifier.addCategory(name: 'Peralatan Masak Tambahan', requiresSize: false);
      final newCat = notifier.state.categories.last;

      notifier.setCategory(newCat.id);
      expect(notifier.state.selectedCategoryId, newCat.id);

      final success = notifier.deleteCategory(newCat.id);
      expect(success, isTrue);
      expect(notifier.state.categories.any((c) => c.id == newCat.id), isFalse);
      expect(notifier.state.selectedCategoryId, 'cat_all');
    });

    test('ItemModel with size variants correctly computes effective total & available stock', () {
      const itemWithSizes = ItemModel(
        id: 'itm_shoe_test',
        categoryId: 'cat_sepatu',
        name: 'Sepatu Hiking Eiger',
        dailyPrice: 35000,
        replacementPrice: 350000,
        totalStock: 0,
        variants: [
          ProductVariantModel(id: 'v1', size: '39', stock: 2, rentedStock: 1),
          ProductVariantModel(id: 'v2', size: '40', stock: 3, rentedStock: 0),
          ProductVariantModel(id: 'v3', size: '41', stock: 4, rentedStock: 2),
          ProductVariantModel(id: 'v4', size: '42', stock: 2, rentedStock: 0),
        ],
      );

      expect(itemWithSizes.hasVariants, isTrue);
      expect(itemWithSizes.effectiveTotalStock, 11);
      expect(itemWithSizes.effectiveRentedStock, 3);
      expect(itemWithSizes.availableStock, 8);
      expect(itemWithSizes.sizesSummary, '39   40   41   42');
    });

    test('ItemModel without size variants uses base totalStock', () {
      const itemNoSize = ItemModel(
        id: 'itm_tent_test',
        categoryId: 'cat_tenda',
        name: 'Tenda Camping 4P',
        dailyPrice: 75000,
        replacementPrice: 600000,
        totalStock: 5,
        rentedStock: 2,
        variants: [],
      );

      expect(itemNoSize.hasVariants, isFalse);
      expect(itemNoSize.effectiveTotalStock, 5);
      expect(itemNoSize.availableStock, 3);
      expect(itemNoSize.sizesSummary, 'Tidak ada');
    });

    test('Non-Owner role (Kasir) cannot add, update, or delete products', () {
      notifier.quickLogin(AppRole.kasir);

      const testItem = ItemModel(
        id: 'itm_unauthorized',
        categoryId: 'cat_tenda',
        name: 'Tenda Ilegal',
        dailyPrice: 50000,
        replacementPrice: 300000,
        totalStock: 2,
      );

      expect(
        () => notifier.addItem(testItem),
        throwsA(isA<StateError>()),
      );

      expect(
        () => notifier.updateItem(testItem),
        throwsA(isA<StateError>()),
      );

      expect(
        () => notifier.deleteItem('itm_01'),
        throwsA(isA<StateError>()),
      );
    });

    test('Cannot delete product if it is in an active rental', () {
      // Find an item currently in an active rental
      final activeRental = notifier.state.rentals.first;
      final rentedItemId = activeRental.items.first.itemId;

      final result = notifier.deleteItem(rentedItemId);
      expect(result, isFalse);
      expect(notifier.state.items.any((it) => it.id == rentedItemId), isTrue);
    });

    test('Cart correctly supports adding items with specific size variants', () {
      const shoeItem = ItemModel(
        id: 'itm_cart_shoe',
        categoryId: 'cat_sepatu',
        name: 'Sepatu Hiking',
        dailyPrice: 35000,
        replacementPrice: 350000,
        totalStock: 0,
        variants: [
          ProductVariantModel(id: 'v1', size: '39', stock: 2),
          ProductVariantModel(id: 'v2', size: '40', stock: 3),
        ],
      );

      notifier.addItemToCart(shoeItem, selectedSize: '39');
      notifier.addItemToCart(shoeItem, selectedSize: '40');

      expect(notifier.state.newRentalForm.cartItems.length, 2);
      expect(notifier.state.newRentalForm.cartItems[0].selectedSize, '39');
      expect(notifier.state.newRentalForm.cartItems[1].selectedSize, '40');
    });
  });
}
