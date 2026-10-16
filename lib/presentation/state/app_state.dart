import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/data/models/printer_model.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
import 'package:camprent_pos/data/dummy_data.dart';
import 'package:camprent_pos/domain/calculator.dart';
import 'package:camprent_pos/data/services/auth_service.dart';
import 'package:camprent_pos/data/services/supabase_service.dart';

enum AppRole {
  admin, // Owner
  kasir, // Staff
}

enum NetworkStatus {
  online,
  offline,
  syncing,
}

class CartItem {
  final ItemModel item;
  final String? selectedSize;
  final int qty;

  const CartItem({
    required this.item,
    this.selectedSize,
    required this.qty,
  });

  CartItem copyWith({ItemModel? item, String? selectedSize, int? qty}) {
    return CartItem(
      item: item ?? this.item,
      selectedSize: selectedSize ?? this.selectedSize,
      qty: qty ?? this.qty,
    );
  }
}

class NewRentalFormState {
  final CustomerModel? selectedCustomer;
  final DateTime pickupDate;
  final DateTime returnDate;
  final List<CartItem> cartItems;
  final int discount;
  final bool useCollateral; // true = KTP/SIM/KTM, false = Deposit uang
  final CollateralType collateralType;
  final String collateralNote;
  final int depositAmount;
  final int dpPercentage; // 50% default
  final PaymentMethod paymentMethod;
  final int cashPaid;
  final String note;

  NewRentalFormState({
    this.selectedCustomer,
    DateTime? pickupDate,
    DateTime? returnDate,
    this.cartItems = const [],
    this.discount = 0,
    this.useCollateral = true,
    this.collateralType = CollateralType.ktp,
    this.collateralNote = '',
    this.depositAmount = 100000,
    this.dpPercentage = 50,
    this.paymentMethod = PaymentMethod.tunai,
    this.cashPaid = 0,
    this.note = '',
  })  : pickupDate = pickupDate ?? DateTime.now(),
        returnDate = returnDate ?? DateTime.now().add(const Duration(days: 2));

  int get durationDays => RentalCalculationEngine.calculateDuration(pickupDate, returnDate);

  int get itemsSubtotal {
    int sum = 0;
    for (final ci in cartItems) {
      int price = ci.item.dailyPrice;
      if (ci.selectedSize != null && ci.item.hasVariants) {
        final variantMatch = ci.item.variants.where((v) => v.size == ci.selectedSize).toList();
        if (variantMatch.isNotEmpty && variantMatch.first.dailyPrice != null) {
          price = variantMatch.first.dailyPrice!;
        }
      }
      sum += RentalCalculationEngine.calculateItemSubtotal(
        dailyPrice: price,
        qty: ci.qty,
        durationDays: durationDays,
      );
    }
    return sum;
  }

  RentalTotals get totals => RentalCalculationEngine.calculateTotals(
        itemsSubtotal: itemsSubtotal,
        discount: discount,
        minDpPercentage: dpPercentage,
      );

  int get totalToPayNow => totals.minDp + (!useCollateral ? depositAmount : 0);

  int get cashChange {
    if (paymentMethod != PaymentMethod.tunai) return 0;
    return cashPaid - totalToPayNow;
  }

  bool get isValidToSubmit {
    if (selectedCustomer == null) return false;
    if (cartItems.isEmpty) return false;
    if (useCollateral && collateralNote.trim().isEmpty) return false;
    if (!useCollateral && depositAmount < 50000) return false;
    if (paymentMethod == PaymentMethod.tunai && cashPaid < totalToPayNow) return false;
    return true;
  }

  NewRentalFormState copyWith({
    CustomerModel? selectedCustomer,
    DateTime? pickupDate,
    DateTime? returnDate,
    List<CartItem>? cartItems,
    int? discount,
    bool? useCollateral,
    CollateralType? collateralType,
    String? collateralNote,
    int? depositAmount,
    int? dpPercentage,
    PaymentMethod? paymentMethod,
    int? cashPaid,
    String? note,
  }) {
    return NewRentalFormState(
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      cartItems: cartItems ?? this.cartItems,
      discount: discount ?? this.discount,
      useCollateral: useCollateral ?? this.useCollateral,
      collateralType: collateralType ?? this.collateralType,
      collateralNote: collateralNote ?? this.collateralNote,
      depositAmount: depositAmount ?? this.depositAmount,
      dpPercentage: dpPercentage ?? this.dpPercentage,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashPaid: cashPaid ?? this.cashPaid,
      note: note ?? this.note,
    );
  }
}

class AppStateData {
  final bool isLoggedIn;
  final AppRole currentRole;
  final String activeCashierName;
  final String deviceCode;
  final NetworkStatus networkStatus;
  final int outboxCount;
  final String selectedCategoryId;
  final String itemSearchQuery;
  final List<CategoryModel> categories;
  final List<ItemModel> items;
  final List<CustomerModel> customers;
  final List<RentalModel> rentals;
  final StoreSettingsModel settings;
  final PrinterConfigModel printerConfig;
  final NewRentalFormState newRentalForm;
  final List<CashierShiftModel> shifts;
  final CashierShiftModel? activeCashierShift;
  final String? storeId;
  final String? storeName;
  final String? userEmail;

  const AppStateData({
    this.isLoggedIn = false,
    required this.currentRole,
    required this.activeCashierName,
    required this.deviceCode,
    required this.networkStatus,
    required this.outboxCount,
    required this.selectedCategoryId,
    required this.itemSearchQuery,
    required this.categories,
    required this.items,
    required this.customers,
    required this.rentals,
    required this.settings,
    required this.printerConfig,
    required this.newRentalForm,
    this.shifts = const [],
    this.activeCashierShift,
    this.storeId,
    this.storeName,
    this.userEmail,
  });

  AppStateData copyWith({
    bool? isLoggedIn,
    AppRole? currentRole,
    String? activeCashierName,
    String? deviceCode,
    NetworkStatus? networkStatus,
    int? outboxCount,
    String? selectedCategoryId,
    String? itemSearchQuery,
    List<CategoryModel>? categories,
    List<ItemModel>? items,
    List<CustomerModel>? customers,
    List<RentalModel>? rentals,
    StoreSettingsModel? settings,
    PrinterConfigModel? printerConfig,
    NewRentalFormState? newRentalForm,
    List<CashierShiftModel>? shifts,
    CashierShiftModel? Function()? activeCashierShift,
    String? storeId,
    String? storeName,
    String? userEmail,
  }) {
    return AppStateData(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      currentRole: currentRole ?? this.currentRole,
      activeCashierName: activeCashierName ?? this.activeCashierName,
      deviceCode: deviceCode ?? this.deviceCode,
      networkStatus: networkStatus ?? this.networkStatus,
      outboxCount: outboxCount ?? this.outboxCount,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      itemSearchQuery: itemSearchQuery ?? this.itemSearchQuery,
      categories: categories ?? this.categories,
      items: items ?? this.items,
      customers: customers ?? this.customers,
      rentals: rentals ?? this.rentals,
      settings: settings ?? this.settings,
      printerConfig: printerConfig ?? this.printerConfig,
      newRentalForm: newRentalForm ?? this.newRentalForm,
      shifts: shifts ?? this.shifts,
      activeCashierShift: activeCashierShift != null ? activeCashierShift() : this.activeCashierShift,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppStateData> {
  AppStateNotifier()
      : super(
          AppStateData(
            isLoggedIn: false,
            currentRole: AppRole.admin,
            activeCashierName: 'Budi Santoso (Owner)',
            deviceCode: 'DEV-A01',
            networkStatus: NetworkStatus.online,
            outboxCount: 0,
            selectedCategoryId: 'cat_all',
            itemSearchQuery: '',
            categories: List<CategoryModel>.from(DummyData.categories),
            items: DummyData.items,
            customers: DummyData.customers,
            rentals: DummyData.getInitialRentals(),
            settings: StoreSettingsModel(
              cashiers: DummyData.cashiers,
              feePresets: DummyData.feePresets,
            ),
            printerConfig: const PrinterConfigModel(),
            newRentalForm: NewRentalFormState(),
            shifts: DummyData.getInitialShifts(),
            activeCashierShift: null,
          ),
        );

  // Authentication & Session
  Future<bool> login({required String email, required String password}) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return false;
    }

    try {
      final authResponse = await AuthService().signIn(
        email: email.trim(),
        password: password,
      );

      if (authResponse.user != null) {
        final profile = await AuthService().getCurrentUserProfile();
        final storeId = profile?['store_id']?.toString();
        final storeData = profile?['stores'];
        final storeName = storeData?['name']?.toString() ?? 'CampRent POS';
        final roleStr = profile?['role']?.toString();
        final isOwner = roleStr == 'owner';
        final cashierName = profile?['name']?.toString() ?? (isOwner ? 'Owner' : 'Kasir');

        List<CategoryModel> remoteCategories = state.categories;
        List<ItemModel> remoteItems = state.items;
        List<CustomerModel> remoteCustomers = state.customers;
        List<RentalModel> remoteRentals = state.rentals;
        List<CashierShiftModel> remoteShifts = state.shifts;
        StoreSettingsModel remoteSettings = state.settings;

        if (storeId != null) {
          final fetchedCats = await SupabaseService().fetchCategories(storeId);
          if (fetchedCats.isNotEmpty) remoteCategories = fetchedCats;

          final fetchedItems = await SupabaseService().fetchItems(storeId);
          if (fetchedItems.isNotEmpty) remoteItems = fetchedItems;

          final fetchedCustomers = await SupabaseService().fetchCustomers(storeId);
          if (fetchedCustomers.isNotEmpty) remoteCustomers = fetchedCustomers;

          final fetchedRentals = await SupabaseService().fetchRentals(storeId);
          if (fetchedRentals.isNotEmpty) remoteRentals = fetchedRentals;

          final fetchedShifts = await SupabaseService().fetchShifts(storeId);
          if (fetchedShifts.isNotEmpty) remoteShifts = fetchedShifts;

          final fetchedSettings = await SupabaseService().fetchStoreSettings(storeId);
          if (fetchedSettings != null) remoteSettings = fetchedSettings;
        }

        state = state.copyWith(
          isLoggedIn: true,
          storeId: storeId,
          storeName: storeName,
          userEmail: email.trim(),
          currentRole: isOwner ? AppRole.admin : AppRole.kasir,
          activeCashierName: isOwner ? '$cashierName (Owner)' : '$cashierName (Kasir)',
          networkStatus: NetworkStatus.online,
          categories: remoteCategories,
          items: remoteItems,
          customers: remoteCustomers,
          rentals: remoteRentals,
          shifts: remoteShifts,
          settings: remoteSettings,
          activeCashierShift: isOwner ? null : () => null,
        );
        return true;
      }
    } catch (e) {
      developer.log('Supabase login exception: $e');
      final lower = email.trim().toLowerCase();
      // Demo / fallback credentials
      if (lower.contains('owner') || lower.contains('admin') || lower == 'demo' || password == '123456' || password == 'admin') {
        final isOwner = lower.contains('owner') || lower.contains('admin') || lower == 'demo';
        state = state.copyWith(
          isLoggedIn: true,
          currentRole: isOwner ? AppRole.admin : AppRole.kasir,
          activeCashierName: isOwner ? 'Owner CampRent' : 'Budi Santoso (Kasir)',
          storeName: 'CampRent Store (Demo/Lokal)',
          networkStatus: NetworkStatus.online,
        );
        return true;
      }
    }
    return false;
  }

  Future<bool> registerStore({
    required String email,
    required String password,
    required String ownerName,
    required String storeName,
    String? phone,
    String? address,
  }) async {
    try {
      final res = await AuthService().registerStoreOwner(
        email: email,
        password: password,
        ownerName: ownerName,
        storeName: storeName,
        phone: phone,
        address: address,
      );
      if (res.user != null) {
        return await login(email: email, password: password);
      }
    } catch (e) {
      developer.log('Register store error: $e');
    }
    return false;
  }

  void quickLogin(AppRole role) {
    if (role == AppRole.admin) {
      state = state.copyWith(
        isLoggedIn: true,
        currentRole: AppRole.admin,
        activeCashierName: 'Owner CampRent',
      );
    } else {
      state = state.copyWith(
        isLoggedIn: true,
        currentRole: AppRole.kasir,
        activeCashierName: 'Budi Santoso (Kasir)',
        activeCashierShift: () => null, // Kasir wajib buka shift sebelum transaksi
      );
    }
  }

  void logout() {
    try {
      AuthService().signOut();
    } catch (_) {}
    state = state.copyWith(
      isLoggedIn: false,
      newRentalForm: NewRentalFormState(),
      activeCashierShift: () => null,
      storeId: null,
      storeName: null,
      userEmail: null,
    );
  }

  // Role toggle
  void setRole(AppRole role) {
    state = state.copyWith(
      currentRole: role,
      activeCashierName: role == AppRole.admin ? 'Owner CampRent' : 'Budi Santoso (Kasir)',
      activeCashierShift: role == AppRole.admin ? null : () => state.activeCashierShift,
    );
  }

  // Shift Management
  void openShift(int initialCash) {
    final now = DateTime.now();
    final newShift = CashierShiftModel(
      id: 'shf_${now.millisecondsSinceEpoch}',
      cashierId: 'cashier_002',
      cashierName: state.activeCashierName.replaceAll(' (Kasir)', ''),
      cashierEmail: state.userEmail ?? 'kasir@camprent.com',
      date: now,
      startTime: now,
      initialCash: initialCash,
      status: ShiftStatus.sedangBerjalan,
    );

    final updatedShifts = List<CashierShiftModel>.from(state.shifts);
    final existingIdx = updatedShifts.indexWhere(
      (s) => s.cashierName == newShift.cashierName && s.status == ShiftStatus.belumBuka,
    );
    if (existingIdx != -1) {
      updatedShifts[existingIdx] = newShift;
    } else {
      updatedShifts.insert(0, newShift);
    }

    state = state.copyWith(
      shifts: updatedShifts,
      activeCashierShift: () => newShift,
    );

    // Sync to Supabase if connected
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().openShift(
        storeId: state.storeId!,
        cashierName: newShift.cashierName,
        initialCash: initialCash,
      );
    }
  }

  void closeShift({required int actualCash, String? discrepancyNote}) {
    if (state.activeCashierShift == null) return;
    final now = DateTime.now();
    final closedShift = state.activeCashierShift!.copyWith(
      endTime: now,
      actualCash: actualCash,
      discrepancyNote: discrepancyNote,
      status: ShiftStatus.selesai,
    );

    final updatedShifts = state.shifts.map((s) => s.id == closedShift.id ? closedShift : s).toList();

    state = state.copyWith(
      shifts: updatedShifts,
      activeCashierShift: () => null,
    );

    // Sync to Supabase if connected
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().closeShift(
        shiftId: closedShift.id,
        actualCash: actualCash,
        expectedCash: closedShift.expectedCash,
        totalCash: closedShift.totalCashPayments,
        totalTransfer: closedShift.totalTransferPayments,
        totalQris: closedShift.totalQrisPayments,
        notes: discrepancyNote,
      );
    }
  }

  // Network toggle simulator & Outbox auto-sync
  void toggleNetwork() {
    if (state.networkStatus == NetworkStatus.online) {
      state = state.copyWith(networkStatus: NetworkStatus.offline, outboxCount: 2);
    } else {
      state = state.copyWith(networkStatus: NetworkStatus.online);
      syncOutbox();
    }
  }

  Future<void> syncOutbox() async {
    if (state.storeId == null || state.networkStatus == NetworkStatus.offline) return;
    state = state.copyWith(networkStatus: NetworkStatus.syncing);
    try {
      // Sync outbox
      state = state.copyWith(
        networkStatus: NetworkStatus.online,
        outboxCount: 0,
      );
    } catch (_) {
      state = state.copyWith(networkStatus: NetworkStatus.online);
    }
  }

  // Category & search
  void setCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void addCategory({required String name, bool requiresSize = false}) {
    if (state.currentRole != AppRole.admin) {
      throw StateError('Anda tidak memiliki izin untuk mengubah data produk.');
    }
    final newCat = CategoryModel(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      requiresSize: requiresSize,
    );
    state = state.copyWith(
      categories: [...state.categories, newCat],
    );

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().insertCategory(
        storeId: state.storeId!,
        name: name,
        requiresSize: requiresSize,
      );
    }
  }

  bool deleteCategory(String categoryId) {
    if (state.currentRole != AppRole.admin) {
      throw StateError('Anda tidak memiliki izin untuk mengubah data produk.');
    }
    if (categoryId == 'cat_all') return false; // "Semua" tidak boleh dihapus

    // Hapus kategori dari daftar
    final updatedCategories = state.categories.where((c) => c.id != categoryId).toList();

    // Jika kategori yang sedang aktif dihapus, reset filter ke 'cat_all'
    final nextSelected = state.selectedCategoryId == categoryId ? 'cat_all' : state.selectedCategoryId;

    // Item yang menggunakan kategori ini dialihkan ke 'cat_all'
    final updatedItems = state.items.map((it) {
      if (it.categoryId == categoryId) {
        return it.copyWith(categoryId: 'cat_all');
      }
      return it;
    }).toList();

    state = state.copyWith(
      categories: updatedCategories,
      selectedCategoryId: nextSelected,
      items: updatedItems,
    );

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().deleteCategory(categoryId);
    }

    return true;
  }

  void updateCategory(CategoryModel updated) {
    if (state.currentRole != AppRole.admin) {
      throw StateError('Anda tidak memiliki izin untuk mengubah data produk.');
    }
    final updatedList = state.categories.map((c) => c.id == updated.id ? updated : c).toList();
    state = state.copyWith(categories: updatedList);
  }

  void setItemSearch(String query) {
    state = state.copyWith(itemSearchQuery: query);
  }

  // Cart operations
  void addItemToCart(ItemModel item, {String? selectedSize}) {
    int available = item.availableStock;
    if (selectedSize != null && item.hasVariants) {
      final v = item.variants.where((v) => v.size == selectedSize).firstOrNull;
      available = v?.availableStock ?? 0;
    }

    final currentList = List<CartItem>.from(state.newRentalForm.cartItems);
    final index = currentList.indexWhere((ci) => ci.item.id == item.id && ci.selectedSize == selectedSize);

    if (index >= 0) {
      final currentQty = currentList[index].qty;
      if (currentQty < available) {
        currentList[index] = currentList[index].copyWith(qty: currentQty + 1);
      }
    } else {
      if (available > 0) {
        currentList.add(CartItem(item: item, selectedSize: selectedSize, qty: 1));
      }
    }

    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(cartItems: currentList),
    );
  }

  void updateCartItemQty(String itemId, int newQty, {String? selectedSize}) {
    final currentList = List<CartItem>.from(state.newRentalForm.cartItems);
    final index = currentList.indexWhere((ci) => ci.item.id == itemId && ci.selectedSize == selectedSize);

    if (index >= 0) {
      if (newQty <= 0) {
        currentList.removeAt(index);
      } else {
        int maxStock = currentList[index].item.availableStock;
        if (selectedSize != null && currentList[index].item.hasVariants) {
          final v = currentList[index].item.variants.where((v) => v.size == selectedSize).firstOrNull;
          maxStock = v?.availableStock ?? 0;
        }
        final clampedQty = newQty > maxStock ? maxStock : newQty;
        currentList[index] = currentList[index].copyWith(qty: clampedQty);
      }
    }

    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(cartItems: currentList),
    );
  }

  void removeCartItem(String itemId, {String? selectedSize}) {
    final currentList = state.newRentalForm.cartItems.where((ci) {
      if (selectedSize != null) {
        return !(ci.item.id == itemId && ci.selectedSize == selectedSize);
      }
      return ci.item.id != itemId;
    }).toList();
    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(cartItems: currentList),
    );
  }

  void clearCart() {
    state = state.copyWith(
      newRentalForm: NewRentalFormState(),
    );
  }

  void selectCustomer(CustomerModel customer) {
    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(selectedCustomer: customer),
    );
  }

  void updateRentalDates(DateTime pickup, DateTime ret) {
    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(
        pickupDate: pickup,
        returnDate: ret,
      ),
    );
  }

  void updateCollateral({
    required bool useCollateral,
    CollateralType? type,
    String? note,
    int? depositAmount,
  }) {
    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(
        useCollateral: useCollateral,
        collateralType: type ?? state.newRentalForm.collateralType,
        collateralNote: note ?? state.newRentalForm.collateralNote,
        depositAmount: depositAmount ?? state.newRentalForm.depositAmount,
      ),
    );
  }

  void updatePaymentDetails({
    int? dpPercentage,
    PaymentMethod? method,
    int? cashPaid,
    int? discount,
  }) {
    state = state.copyWith(
      newRentalForm: state.newRentalForm.copyWith(
        dpPercentage: dpPercentage ?? state.newRentalForm.dpPercentage,
        paymentMethod: method ?? state.newRentalForm.paymentMethod,
        cashPaid: cashPaid ?? state.newRentalForm.cashPaid,
        discount: discount ?? state.newRentalForm.discount,
      ),
    );
  }

  /// Create and save rental (PRD 5.4)
  RentalModel? submitNewRental() {
    final form = state.newRentalForm;
    if (!form.isValidToSubmit) return null;

    final totals = form.totals;
    final now = DateTime.now();
    final rentalNumber = 'RNT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-A-${(state.rentals.length + 1).toString().padLeft(4, '0')}';

    final rentalItems = form.cartItems.map((ci) {
      int price = ci.item.dailyPrice;
      if (ci.selectedSize != null && ci.item.hasVariants) {
        final variantMatch = ci.item.variants.where((v) => v.size == ci.selectedSize).toList();
        if (variantMatch.isNotEmpty && variantMatch.first.dailyPrice != null) {
          price = variantMatch.first.dailyPrice!;
        }
      }
      return RentalItemModel(
        id: 'ri_${now.millisecondsSinceEpoch}_${ci.item.id}_${ci.selectedSize ?? "def"}',
        itemId: ci.item.id,
        nameSnapshot: ci.item.name,
        selectedSize: ci.selectedSize,
        priceSnapshot: price,
        replacementPriceSnapshot: ci.item.replacementPrice,
        qty: ci.qty,
      );
    }).toList();

    // Kurangi stok alat (baik total maupun varian)
    final updatedItems = state.items.map((it) {
      final matchingCartItems = form.cartItems.where((ci) => ci.item.id == it.id).toList();
      if (matchingCartItems.isEmpty) return it;

      int addedRented = 0;
      for (final ci in matchingCartItems) {
        addedRented += ci.qty;
      }

      if (it.hasVariants) {
        final updatedVariants = it.variants.map((v) {
          final vCart = matchingCartItems.where((ci) => ci.selectedSize == v.size).firstOrNull;
          if (vCart != null) {
            return v.copyWith(rentedStock: v.rentedStock + vCart.qty);
          }
          return v;
        }).toList();
        return it.copyWith(
          variants: updatedVariants,
          rentedStock: it.rentedStock + addedRented,
        );
      }

      return it.copyWith(rentedStock: it.rentedStock + addedRented);
    }).toList();

    final payments = [
      PaymentRecord(
        id: 'pay_${now.millisecondsSinceEpoch}',
        type: PaymentType.dp,
        method: form.paymentMethod,
        amount: totals.minDp,
        time: now,
        cashierName: state.activeCashierName,
      ),
      if (!form.useCollateral)
        PaymentRecord(
          id: 'pay_dep_${now.millisecondsSinceEpoch}',
          type: PaymentType.deposit,
          method: form.paymentMethod,
          amount: form.depositAmount,
          time: now,
          cashierName: state.activeCashierName,
        ),
    ];

    final newRental = RentalModel(
      id: 'rnt_${now.millisecondsSinceEpoch}',
      rentalNumber: rentalNumber,
      customer: form.selectedCustomer!,
      cashierName: state.activeCashierName,
      pickupDate: form.pickupDate,
      scheduledReturnDate: form.returnDate,
      durationDays: form.durationDays,
      subtotal: totals.subtotal,
      discount: totals.discount,
      totalSewa: totals.totalSewa,
      dpPaid: totals.minDp,
      status: RentalStatus.aktif,
      items: rentalItems,
      collateral: form.useCollateral
          ? CollateralModel(
              type: form.collateralType,
              note: form.collateralNote,
              isReturned: false,
            )
          : null,
      deposit: !form.useCollateral
          ? DepositModel(
              amount: form.depositAmount,
              usedAmount: 0,
              refundedAmount: 0,
            )
          : null,
      payments: payments,
      note: form.note,
    );

    // Update customer rental count
    final updatedCustomers = state.customers.map((c) {
      if (c.id == form.selectedCustomer!.id) {
        return c.copyWith(totalRentals: c.totalRentals + 1);
      }
      return c;
    }).toList();

    final outboxIncrement = state.networkStatus == NetworkStatus.offline ? 1 : 0;

    // Update active cashier shift metrics if in active shift
    List<CashierShiftModel> updatedShiftsList = state.shifts;
    CashierShiftModel? updatedActiveShift = state.activeCashierShift;
    if (updatedActiveShift != null) {
      final cashInc = form.paymentMethod == PaymentMethod.tunai ? form.totalToPayNow : 0;
      final transferInc = form.paymentMethod == PaymentMethod.transfer ? form.totalToPayNow : 0;
      final qrisInc = form.paymentMethod == PaymentMethod.qris ? form.totalToPayNow : 0;

      final shift = updatedActiveShift.copyWith(
        totalTransactions: updatedActiveShift.totalTransactions + 1,
        totalCashPayments: updatedActiveShift.totalCashPayments + cashInc,
        totalTransferPayments: updatedActiveShift.totalTransferPayments + transferInc,
        totalQrisPayments: updatedActiveShift.totalQrisPayments + qrisInc,
      );
      updatedActiveShift = shift;
      updatedShiftsList = updatedShiftsList.map((s) => s.id == shift.id ? shift : s).toList();
    }

    state = state.copyWith(
      items: updatedItems,
      customers: updatedCustomers,
      rentals: [newRental, ...state.rentals],
      outboxCount: state.outboxCount + outboxIncrement,
      newRentalForm: NewRentalFormState(), // reset form
      shifts: updatedShiftsList,
      activeCashierShift: () => updatedActiveShift,
    );

    // Sync to Supabase if connected
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().createRental(
        storeId: state.storeId!,
        rental: newRental,
        shiftId: updatedActiveShift?.id,
      );
    }

    return newRental;
  }

  /// Process Return and Settlement (PRD 5.5)
  RentalModel processReturnSettlement({
    required String rentalId,
    required List<RentalItemModel> updatedItems,
    required List<RentalFeeItem> appliedFees,
    required SettlementSummary settlement,
    required PaymentMethod paymentMethod,
    required bool returnCollateralPhysical,
  }) {
    final now = DateTime.now();
    final rentalIndex = state.rentals.indexWhere((r) => r.id == rentalId);
    if (rentalIndex < 0) throw Exception('Rental not found');

    final originalRental = state.rentals[rentalIndex];

    // Cek apakah semua item sudah kembali penuh
    final isFullyReturned = updatedItems.every((it) => it.returnedQty >= it.qty);

    // Update stok: kembalikan stok sewa, jika rusak tambah stok rusak, jika hilang kurangi stok total
    final updatedGlobalItems = List<ItemModel>.from(state.items);
    for (final itm in updatedItems) {
      final gIndex = updatedGlobalItems.indexWhere((g) => g.id == itm.itemId);
      if (gIndex >= 0) {
        final g = updatedGlobalItems[gIndex];
        int newRented = g.rentedStock - itm.qty;
        if (newRented < 0) newRented = 0;
        int newDamaged = g.damagedStock;
        int newTotal = g.totalStock;

        if (itm.condition == ItemCondition.rusak) {
          newDamaged += itm.qty;
        } else if (itm.condition == ItemCondition.hilang) {
          newTotal -= itm.qty;
        }

        updatedGlobalItems[gIndex] = g.copyWith(
          rentedStock: newRented,
          damagedStock: newDamaged,
          totalStock: newTotal,
        );
      }
    }

    final newPayments = List<PaymentRecord>.from(originalRental.payments);
    if (settlement.remainingToPay > 0) {
      newPayments.add(
        PaymentRecord(
          id: 'pay_pelunasan_${now.millisecondsSinceEpoch}',
          type: PaymentType.pelunasan,
          method: paymentMethod,
          amount: settlement.remainingToPay,
          time: now,
          cashierName: state.activeCashierName,
        ),
      );
    }

    final updatedCollateral = originalRental.collateral?.copyWith(
      isReturned: returnCollateralPhysical,
      returnedAt: returnCollateralPhysical ? now : null,
    );

    final updatedDeposit = originalRental.deposit?.copyWith(
      usedAmount: settlement.depositUsed,
      refundedAmount: settlement.depositRefund,
      isSettled: isFullyReturned,
    );

    final finishedRental = originalRental.copyWith(
      actualReturnDate: now,
      status: isFullyReturned ? RentalStatus.selesai : RentalStatus.dikembalikanSebagian,
      items: updatedItems,
      fees: appliedFees,
      payments: newPayments,
      collateral: updatedCollateral,
      deposit: updatedDeposit,
    );

    final updatedRentals = List<RentalModel>.from(state.rentals);
    updatedRentals[rentalIndex] = finishedRental;

    // Update active cashier shift metrics if in active shift
    List<CashierShiftModel> updatedShiftsList = state.shifts;
    CashierShiftModel? updatedActiveShift = state.activeCashierShift;
    if (updatedActiveShift != null && settlement.remainingToPay > 0) {
      final cashInc = paymentMethod == PaymentMethod.tunai ? settlement.remainingToPay : 0;
      final transferInc = paymentMethod == PaymentMethod.transfer ? settlement.remainingToPay : 0;
      final qrisInc = paymentMethod == PaymentMethod.qris ? settlement.remainingToPay : 0;

      final shift = updatedActiveShift.copyWith(
        totalTransactions: updatedActiveShift.totalTransactions + 1,
        totalCashPayments: updatedActiveShift.totalCashPayments + cashInc,
        totalTransferPayments: updatedActiveShift.totalTransferPayments + transferInc,
        totalQrisPayments: updatedActiveShift.totalQrisPayments + qrisInc,
      );
      updatedActiveShift = shift;
      updatedShiftsList = updatedShiftsList.map((s) => s.id == shift.id ? shift : s).toList();
    }

    state = state.copyWith(
      items: updatedGlobalItems,
      rentals: updatedRentals,
      outboxCount: state.networkStatus == NetworkStatus.offline ? state.outboxCount + 1 : state.outboxCount,
      shifts: updatedShiftsList,
      activeCashierShift: () => updatedActiveShift,
    );

    // Sync to Supabase if connected
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().updateRentalStatus(
        rentalId: finishedRental.id,
        status: finishedRental.status,
        paidAmount: finishedRental.dpPaid + settlement.remainingToPay,
        lateFee: finishedRental.fees.where((f) => f.type == 'telat').fold<int>(0, (sum, f) => sum + f.amount),
        damageFee: finishedRental.fees.where((f) => f.type != 'telat').fold<int>(0, (sum, f) => sum + f.amount),
      );
    }

    return finishedRental;
  }

  // Helper: Cek apakah item atau varian sedang dalam transaksi rental aktif
  bool isItemInActiveRental(String itemId) {
    return state.rentals.any((r) =>
        (r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian) &&
        r.items.any((ri) => ri.itemId == itemId));
  }

  bool isVariantInActiveRental(String itemId, String size) {
    return state.rentals.any((r) =>
        (r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian) &&
        r.items.any((ri) => ri.itemId == itemId && ri.selectedSize == size));
  }

  void _verifyOwnerAuthorization() {
    if (state.currentRole != AppRole.admin) {
      throw StateError('Anda tidak memiliki izin untuk mengubah data produk.');
    }
  }

  // Product / Item CRUD (Owner only per PRD 5.2 & Table 2)
  void addItem(ItemModel item) {
    _verifyOwnerAuthorization();
    state = state.copyWith(
      items: [item, ...state.items],
    );
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveItem(storeId: state.storeId!, item: item);
    }
  }

  void updateItem(ItemModel item) {
    _verifyOwnerAuthorization();
    final updated = state.items.map((it) => it.id == item.id ? item : it).toList();
    state = state.copyWith(items: updated);
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveItem(storeId: state.storeId!, item: item);
    }
  }

  void toggleItemActive(String itemId) {
    _verifyOwnerAuthorization();
    final updated = state.items.map((it) {
      if (it.id == itemId) {
        return it.copyWith(isActive: !it.isActive);
      }
      return it;
    }).toList();
    state = state.copyWith(items: updated);
  }

  bool deleteItem(String itemId) {
    _verifyOwnerAuthorization();
    if (isItemInActiveRental(itemId)) {
      return false; // Produk sedang digunakan dalam transaksi aktif dan tidak dapat dihapus.
    }
    final updated = state.items.where((it) => it.id != itemId).toList();
    state = state.copyWith(items: updated);
    return true;
  }

  // Customer Management
  void addCustomer(CustomerModel customer) {
    state = state.copyWith(
      customers: [customer, ...state.customers],
    );
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveCustomer(storeId: state.storeId!, customer: customer);
    }
  }

  void toggleCustomerBlacklist(String customerId, {String? reason}) {
    final updated = state.customers.map((c) {
      if (c.id == customerId) {
        final nextStatus = !c.isBlacklisted;
        return c.copyWith(
          isBlacklisted: nextStatus,
          blacklistReason: nextStatus ? (reason ?? 'Diblacklist oleh owner') : null,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(customers: updated);
  }

  // Printer Settings
  void updatePrinterConfig(PrinterConfigModel newConfig) {
    state = state.copyWith(printerConfig: newConfig);
  }

  // Cashier Account Management (Constraint MAX_KASIR_AKTIF = 3)
  bool addCashier({required String name, required String email}) {
    if (state.settings.isCashierSlotFull) {
      return false; // Ditolak karena slot aktif sudah mencapai 3
    }

    final newCashier = CashierAccountModel(
      id: 'cashier_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final updatedList = [...state.settings.cashiers, newCashier];
    state = state.copyWith(
      settings: state.settings.copyWith(cashiers: updatedList),
    );
    return true;
  }

  bool toggleCashierStatus(String cashierId) {
    final currentCashier = state.settings.cashiers.firstWhere((c) => c.id == cashierId);
    // Jika mau mengaktifkan kasir yang nonaktif, cek apakah slot sudah penuh
    if (!currentCashier.isActive && state.settings.isCashierSlotFull) {
      return false; // Tidak bisa aktifkan karena sudah 3 kasir aktif
    }

    final updatedList = state.settings.cashiers.map((c) {
      if (c.id == cashierId) {
        return c.copyWith(isActive: !c.isActive);
      }
      return c;
    }).toList();

    state = state.copyWith(
      settings: state.settings.copyWith(cashiers: updatedList),
    );
    return true;
  }

  void updateStoreSettings(StoreSettingsModel newSettings) {
    state = state.copyWith(settings: newSettings);
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppStateData>((ref) {
  return AppStateNotifier();
});
