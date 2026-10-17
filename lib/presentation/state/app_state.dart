import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/data/models/printer_model.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
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
    this.isStorePremium = false,
  })  : pickupDate = pickupDate ?? DateTime.now(),
        returnDate = returnDate ?? DateTime.now().add(const Duration(days: 2));

  final bool isStorePremium;

  int get durationDays => RentalCalculationEngine.calculateDuration(pickupDate, returnDate);

  int get itemsSubtotal {
    int sum = 0;
    for (final ci in cartItems) {
      int price = ci.item.getPriceForDuration(durationDays, isStorePremium: isStorePremium);
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
    bool? isStorePremium,
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
      isStorePremium: isStorePremium ?? this.isStorePremium,
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
  final bool isInitializingAuth;

  const AppStateData({
    this.isLoggedIn = false,
    this.isInitializingAuth = true,
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

  bool get isStorePremium => settings.isPremium;

  AppStateData copyWith({
    bool? isLoggedIn,
    bool? isInitializingAuth,
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
      isInitializingAuth: isInitializingAuth ?? this.isInitializingAuth,
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
  static const List<CategoryModel> standardCategories = [
    CategoryModel(id: 'cat_all', name: 'Semua Kategori', requiresSize: false),
    CategoryModel(id: 'cat_tenda', name: 'Tenda & Shelter', requiresSize: false),
    CategoryModel(id: 'cat_carrier', name: 'Tas & Carrier', requiresSize: false),
    CategoryModel(id: 'cat_sepatu', name: 'Sepatu Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_sandal', name: 'Sandal', requiresSize: true),
    CategoryModel(id: 'cat_jaket', name: 'Jaket & Outerwear', requiresSize: true),
    CategoryModel(id: 'cat_celana', name: 'Celana Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_pakaian', name: 'Pakaian Outdoor', requiresSize: true),
    CategoryModel(id: 'cat_sarung_tangan', name: 'Sarung Tangan', requiresSize: true),
    CategoryModel(id: 'cat_sleeping', name: 'Sleeping Gear', requiresSize: false),
    CategoryModel(id: 'cat_furniture', name: 'Camping Furniture', requiresSize: false),
    CategoryModel(id: 'cat_cooking', name: 'Cooking & Dining', requiresSize: false),
    CategoryModel(id: 'cat_penerangan', name: 'Penerangan', requiresSize: false),
    CategoryModel(id: 'cat_elektronik', name: 'Elektronik Outdoor', requiresSize: false),
    CategoryModel(id: 'cat_survival', name: 'Survival & Safety', requiresSize: false),
    CategoryModel(id: 'cat_pendukung', name: 'Peralatan Pendukung', requiresSize: false),
  ];

  AppStateNotifier()
      : super(
          AppStateData(
            isLoggedIn: false,
            isInitializingAuth: true,
            currentRole: AppRole.admin,
            activeCashierName: '',
            deviceCode: 'DEV-A01',
            networkStatus: NetworkStatus.online,
            outboxCount: 0,
            selectedCategoryId: 'cat_all',
            itemSearchQuery: '',
            categories: standardCategories,
            items: const [],
            customers: const [],
            rentals: const [],
            settings: const StoreSettingsModel(),
            printerConfig: const PrinterConfigModel(),
            newRentalForm: NewRentalFormState(),
            shifts: const [],
            activeCashierShift: null,
          ),
        ) {
    initSessionAndRestore();
  }

  String? lastAuthError;

  /// Helper untuk memuat dan menghidrasi seluruh data toko dari Supabase
  Future<void> _hydrateStoreData({
    required String? storeId,
    required String storeName,
    required String email,
    required bool isOwner,
    required String cashierName,
  }) async {
    List<CategoryModel> remoteCategories = state.categories;
    List<ItemModel> remoteItems = state.items;
    List<CustomerModel> remoteCustomers = state.customers;
    List<RentalModel> remoteRentals = state.rentals;
    List<CashierShiftModel> remoteShifts = state.shifts;
    StoreSettingsModel remoteSettings = state.settings;

    if (storeId != null) {
      final fetchedCats = await SupabaseService().fetchCategories(storeId);
      if (fetchedCats.isNotEmpty) {
        final hasAll = fetchedCats.any((c) => c.id == 'cat_all');
        remoteCategories = hasAll
            ? fetchedCats
            : [
                const CategoryModel(id: 'cat_all', name: 'Semua Kategori', requiresSize: false),
                ...fetchedCats,
              ];
      } else {
        remoteCategories = standardCategories;
      }

      final fetchedItems = await SupabaseService().fetchItems(storeId);
      remoteItems = fetchedItems;

      final fetchedCustomers = await SupabaseService().fetchCustomers(storeId);
      remoteCustomers = fetchedCustomers;

      final fetchedRentals = await SupabaseService().fetchRentals(storeId);
      remoteRentals = fetchedRentals;

      final fetchedShifts = await SupabaseService().fetchShifts(storeId);
      remoteShifts = fetchedShifts;

      final fetchedSettings = await SupabaseService().fetchStoreSettings(storeId);
      final fetchedCashiers = await SupabaseService().fetchCashiers(storeId);

      final resolvedCashiers = fetchedCashiers.isNotEmpty
          ? [fetchedCashiers.first.copyWith(isActive: true)]
          : <CashierAccountModel>[];

      if (fetchedSettings != null) {
        remoteSettings = fetchedSettings.copyWith(
          cashiers: resolvedCashiers,
          feePresets: StoreSettingsModel.defaultFeePresets,
        );
      } else {
        remoteSettings = StoreSettingsModel(
          storeName: storeName,
          cashiers: resolvedCashiers,
          feePresets: StoreSettingsModel.defaultFeePresets,
        );
      }
    }

    CashierShiftModel? existingActiveShift;
    if (!isOwner) {
      final cleanCashierName = cashierName.replaceAll(' (Kasir)', '').trim().toLowerCase();
      existingActiveShift = remoteShifts.where((s) =>
        s.status == ShiftStatus.sedangBerjalan &&
        (s.cashierName.trim().toLowerCase() == cleanCashierName ||
         (email.trim().isNotEmpty && s.cashierEmail.trim().toLowerCase() == email.trim().toLowerCase()))
      ).firstOrNull;
    }

    state = state.copyWith(
      isLoggedIn: true,
      isInitializingAuth: false,
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
      activeCashierShift: isOwner ? null : () => existingActiveShift,
    );
  }

  /// Memeriksa dan memulihkan sesi Supabase saat aplikasi dibuka / direfresh
  Future<void> initSessionAndRestore() async {
    try {
      final session = AuthService().currentSession;
      final user = AuthService().currentUser;

      if (session != null && user != null) {
        final profile = await AuthService().getCurrentUserProfile();
        if (profile != null) {
          final storeId = profile['store_id']?.toString();
          final storeData = profile['stores'];
          final storeName = storeData?['name']?.toString() ?? 'CampRent POS';
          final roleStr = profile['role']?.toString();
          final isOwner = roleStr == 'owner';
          final cashierName = profile['name']?.toString() ?? (isOwner ? 'Owner' : 'Kasir');

          await _hydrateStoreData(
            storeId: storeId,
            storeName: storeName,
            email: user.email ?? '',
            isOwner: isOwner,
            cashierName: cashierName,
          );
          return;
        }
      }
    } catch (e) {
      developer.log('Error initializing session: $e');
    } finally {
      if (mounted) {
        state = state.copyWith(isInitializingAuth: false);
      }
    }
  }

  // Authentication & Session
  Future<bool> login({required String email, required String password}) async {
    lastAuthError = null;
    if (email.trim().isEmpty || password.trim().isEmpty) {
      lastAuthError = 'Email dan kata sandi wajib diisi.';
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

        await _hydrateStoreData(
          storeId: storeId,
          storeName: storeName,
          email: email.trim(),
          isOwner: isOwner,
          cashierName: cashierName,
        );
        return true;
      }
    } catch (e) {
      developer.log('Supabase login exception: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('email not confirmed')) {
        lastAuthError = 'Email kasir belum diverifikasi. Di Supabase Auth, matikan opsi "Confirm email" pada menu Providers -> Email, atau jalankan fungsi SQL set_cashier_credentials.';
      } else if (errStr.contains('invalid login credentials') || errStr.contains('invalid_grant')) {
        lastAuthError = 'Email atau kata sandi tidak valid. Pastikan akun kasir sudah didaftarkan dan kata sandi benar.';
      } else {
        lastAuthError = 'Gagal login: $e';
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

  void setStorePremium(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(isPremium: value),
      newRentalForm: state.newRentalForm.copyWith(isStorePremium: value),
    );
  }

  // Role toggle
  void setRole(AppRole role) {
    final firstCashier = state.settings.cashiers.isNotEmpty
        ? state.settings.cashiers.first.name
        : 'Budi Santoso';
    state = state.copyWith(
      currentRole: role,
      activeCashierName: role == AppRole.admin ? 'Owner CampRent' : '$firstCashier (Kasir)',
      activeCashierShift: role == AppRole.admin ? null : () => state.activeCashierShift,
    );
  }

  static int _shiftSeq = 0;

  // Shift Management
  void openShift(int initialCash) {
    final now = DateTime.now();
    _shiftSeq++;
    final cleanCashierName = state.activeCashierName.replaceAll(' (Kasir)', '').replaceAll(' (Owner)', '').trim();
    final newShift = CashierShiftModel(
      id: 'shf_${now.millisecondsSinceEpoch}_$_shiftSeq',
      cashierId: 'cashier_002',
      cashierName: cleanCashierName,
      cashierEmail: state.userEmail ?? 'kasir@camprent.com',
      date: now,
      startTime: now,
      initialCash: initialCash,
      status: ShiftStatus.sedangBerjalan,
    );

    // Otomatis selesaikan shift aktif sebelumnya untuk kasir ini agar tidak terjadi duplikasi
    final updatedShifts = state.shifts.map((s) {
      if (s.cashierName.toLowerCase().trim() == cleanCashierName.toLowerCase() &&
          s.status == ShiftStatus.sedangBerjalan) {
        return s.copyWith(
          endTime: now,
          status: ShiftStatus.selesai,
          actualCash: s.expectedCash,
          discrepancyNote: 'Ditutup otomatis karena kasir membuka shift baru.',
        );
      }
      return s;
    }).toList();

    // Hapus placeholder 'belumBuka' jika ada
    updatedShifts.removeWhere(
      (s) => s.cashierName.toLowerCase().trim() == cleanCashierName.toLowerCase() && s.status == ShiftStatus.belumBuka,
    );

    updatedShifts.insert(0, newShift);

    state = state.copyWith(
      shifts: updatedShifts,
      activeCashierShift: () => newShift,
    );

    // Sync to Supabase if connected
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().openShift(
        storeId: state.storeId!,
        cashierName: cleanCashierName,
        initialCash: initialCash,
      ).then((savedId) {
        if (savedId != null && savedId != newShift.id) {
          final mapped = state.shifts.map((s) => s.id == newShift.id ? s.copyWith(id: savedId) : s).toList();
          state = state.copyWith(
            shifts: mapped,
            activeCashierShift: () => newShift.copyWith(id: savedId),
          );
        }
      });
    }
  }

  Future<bool> closeShift({required int actualCash, String? discrepancyNote}) async {
    if (state.activeCashierShift == null) return false;
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
      return await SupabaseService().closeShift(
        shiftId: closedShift.id,
        storeId: state.storeId,
        cashierName: closedShift.cashierName,
        actualCash: actualCash,
        expectedCash: closedShift.expectedCash,
        totalCash: closedShift.totalCashPayments,
        totalTransfer: closedShift.totalTransferPayments,
        totalQris: closedShift.totalQrisPayments,
        notes: discrepancyNote,
      );
    }
    return true;
  }

  /// Khusus Owner: Menutup paksa shift tertentu berdasarkan ID (misal untuk audit / shift ganda)
  Future<bool> closeShiftById({
    required String shiftId,
    required int actualCash,
    String? discrepancyNote,
  }) async {
    _verifyOwnerAuthorization();
    final now = DateTime.now();
    final shiftIdx = state.shifts.indexWhere((s) => s.id == shiftId);
    if (shiftIdx == -1) return false;

    final targetShift = state.shifts[shiftIdx];
    final closedShift = targetShift.copyWith(
      endTime: now,
      actualCash: actualCash,
      discrepancyNote: discrepancyNote,
      status: ShiftStatus.selesai,
    );

    final updatedShifts = List<CashierShiftModel>.from(state.shifts);
    updatedShifts[shiftIdx] = closedShift;

    final isActiveShift = state.activeCashierShift?.id == shiftId;

    state = state.copyWith(
      shifts: updatedShifts,
      activeCashierShift: isActiveShift ? () => null : () => state.activeCashierShift,
    );

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      return await SupabaseService().closeShift(
        shiftId: closedShift.id,
        storeId: state.storeId,
        cashierName: closedShift.cashierName,
        actualCash: actualCash,
        expectedCash: closedShift.expectedCash,
        totalCash: closedShift.totalCashPayments,
        totalTransfer: closedShift.totalTransferPayments,
        totalQris: closedShift.totalQrisPayments,
        notes: discrepancyNote,
      );
    }
    return true;
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
      int price = ci.item.getPriceForDuration(form.durationDays, isStorePremium: state.isStorePremium);
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
      ).then((remoteId) {
        if (remoteId != null && remoteId != newRental.id) {
          final updatedList = state.rentals.map((r) => r.rentalNumber == newRental.rentalNumber ? r.copyWith(id: remoteId) : r).toList();
          state = state.copyWith(rentals: updatedList);
        }
      });

      // Sinkronisasi status stok berkurang ke tabel items Supabase
      for (final ci in form.cartItems) {
        final updatedItm = updatedItems.where((it) => it.id == ci.item.id).firstOrNull;
        if (updatedItm != null) {
          SupabaseService().saveItem(storeId: state.storeId!, item: updatedItm);
        }
      }
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
        List<ProductVariantModel> updatedVariants = List.from(g.variants);

        if (g.hasVariants && itm.selectedSize != null) {
          final vIdx = updatedVariants.indexWhere((v) => v.size == itm.selectedSize);
          if (vIdx >= 0) {
            final v = updatedVariants[vIdx];
            int vRented = v.rentedStock - itm.qty;
            if (vRented < 0) vRented = 0;
            int vDamaged = v.damagedStock;
            int vStock = v.stock;

            if (itm.condition == ItemCondition.rusak) {
              vDamaged += itm.qty;
            } else if (itm.condition == ItemCondition.hilang) {
              vStock -= itm.qty;
              if (vStock < 0) vStock = 0;
            }

            updatedVariants[vIdx] = v.copyWith(
              rentedStock: vRented,
              damagedStock: vDamaged,
              stock: vStock,
            );
          }
          newRented = updatedVariants.fold(0, (sum, v) => sum + v.rentedStock);
          newDamaged = updatedVariants.fold(0, (sum, v) => sum + v.damagedStock);
          newTotal = updatedVariants.fold(0, (sum, v) => sum + v.stock);
        } else {
          if (itm.condition == ItemCondition.rusak) {
            newDamaged += itm.qty;
          } else if (itm.condition == ItemCondition.hilang) {
            newTotal -= itm.qty;
            if (newTotal < 0) newTotal = 0;
          }
        }

        updatedGlobalItems[gIndex] = g.copyWith(
          rentedStock: newRented,
          damagedStock: newDamaged,
          totalStock: newTotal,
          variants: updatedVariants,
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
        invoiceNumber: finishedRental.rentalNumber,
        status: finishedRental.status,
        paidAmount: finishedRental.dpPaid + settlement.remainingToPay,
        lateFee: finishedRental.fees.where((f) => f.type == 'telat').fold<int>(0, (sum, f) => sum + f.amount),
        damageFee: finishedRental.fees.where((f) => f.type != 'telat').fold<int>(0, (sum, f) => sum + f.amount),
      );

      // Sinkronisasi status stok terbaru ke tabel items Supabase
      for (final itm in updatedItems) {
        final g = updatedGlobalItems.where((g) => g.id == itm.itemId).firstOrNull;
        if (g != null) {
          SupabaseService().saveItem(storeId: state.storeId!, item: g);
        }
      }
    }

    return finishedRental;
  }

  /// Mengembalikan stok yang sedang disewa menjadi tersedia secara manual (khusus Owner)
  void returnRentedStockManually({
    required String itemId,
    required int returnQty,
    String? variantSize,
  }) {
    _verifyOwnerAuthorization();
    final idx = state.items.indexWhere((it) => it.id == itemId);
    if (idx < 0) return;

    final item = state.items[idx];
    ItemModel updatedItem;

    if (variantSize != null && item.hasVariants) {
      final updatedVariants = item.variants.map((v) {
        if (v.size == variantSize) {
          int newRented = v.rentedStock - returnQty;
          if (newRented < 0) newRented = 0;
          return v.copyWith(rentedStock: newRented);
        }
        return v;
      }).toList();

      final totalRented = updatedVariants.fold(0, (sum, v) => sum + v.rentedStock);
      updatedItem = item.copyWith(
        rentedStock: totalRented,
        variants: updatedVariants,
      );
    } else {
      int newRented = item.rentedStock - returnQty;
      if (newRented < 0) newRented = 0;
      updatedItem = item.copyWith(rentedStock: newRented);
    }

    final newItems = List<ItemModel>.from(state.items);
    newItems[idx] = updatedItem;
    state = state.copyWith(items: newItems);

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveItem(storeId: state.storeId!, item: updatedItem);
    }
  }

  /// Mengatur langsung stok sewa / total stok produk (Direct Stock Adjustment)
  void adjustItemStock({
    required String itemId,
    int? newTotalStock,
    int? newRentedStock,
    int? newDamagedStock,
    String? variantSize,
  }) {
    _verifyOwnerAuthorization();
    final idx = state.items.indexWhere((it) => it.id == itemId);
    if (idx < 0) return;

    final item = state.items[idx];
    ItemModel updatedItem;

    if (variantSize != null && item.hasVariants) {
      final updatedVariants = item.variants.map((v) {
        if (v.size == variantSize) {
          return v.copyWith(
            stock: newTotalStock ?? v.stock,
            rentedStock: newRentedStock != null ? (newRentedStock < 0 ? 0 : newRentedStock) : v.rentedStock,
            damagedStock: newDamagedStock != null ? (newDamagedStock < 0 ? 0 : newDamagedStock) : v.damagedStock,
          );
        }
        return v;
      }).toList();

      final totalStock = updatedVariants.fold(0, (sum, v) => sum + v.stock);
      final totalRented = updatedVariants.fold(0, (sum, v) => sum + v.rentedStock);
      final totalDamaged = updatedVariants.fold(0, (sum, v) => sum + v.damagedStock);

      updatedItem = item.copyWith(
        totalStock: totalStock,
        rentedStock: totalRented,
        damagedStock: totalDamaged,
        variants: updatedVariants,
      );
    } else {
      updatedItem = item.copyWith(
        totalStock: newTotalStock ?? item.totalStock,
        rentedStock: newRentedStock != null ? (newRentedStock < 0 ? 0 : newRentedStock) : item.rentedStock,
        damagedStock: newDamagedStock != null ? (newDamagedStock < 0 ? 0 : newDamagedStock) : item.damagedStock,
      );
    }

    final newItems = List<ItemModel>.from(state.items);
    newItems[idx] = updatedItem;
    state = state.copyWith(items: newItems);

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveItem(storeId: state.storeId!, item: updatedItem);
    }
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
      SupabaseService().saveItem(storeId: state.storeId!, item: item).then((savedId) {
        if (savedId != null && savedId != item.id) {
          final updated = state.items.map((it) => it.id == item.id ? it.copyWith(id: savedId) : it).toList();
          state = state.copyWith(items: updated);
        }
      });
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

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().deleteItem(itemId);
    }
    return true;
  }

  // Customer Management
  void addCustomer(CustomerModel customer) {
    state = state.copyWith(
      customers: [customer, ...state.customers],
    );
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveCustomer(storeId: state.storeId!, customer: customer).then((remoteId) {
        if (remoteId != null && remoteId != customer.id) {
          final updated = state.customers.map((c) => c.phone == customer.phone ? c.copyWith(id: remoteId) : c).toList();
          state = state.copyWith(customers: updated);
        }
      });
    }
  }

  bool deleteCustomer(String customerId) {
    _verifyOwnerAuthorization();
    final hasActiveRentals = state.rentals.any((r) =>
        (r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian) &&
        r.customer.id == customerId);
    if (hasActiveRentals) {
      return false; // Pelanggan memiliki transaksi rental aktif dan tidak dapat dihapus
    }

    final updated = state.customers.where((c) => c.id != customerId).toList();
    state = state.copyWith(customers: updated);

    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().deleteCustomer(customerId);
    }
    return true;
  }

  void toggleCustomerBlacklist(String customerId, {String? reason}) {
    CustomerModel? modifiedCustomer;
    final updated = state.customers.map((c) {
      if (c.id == customerId) {
        final nextStatus = !c.isBlacklisted;
        final res = CustomerModel(
          id: c.id,
          name: c.name,
          phone: c.phone,
          address: c.address,
          note: c.note,
          isBlacklisted: nextStatus,
          blacklistReason: nextStatus ? (reason ?? 'Diblacklist oleh owner') : null,
          totalRentals: c.totalRentals,
        );
        modifiedCustomer = res;
        return res;
      }
      return c;
    }).toList();

    state = state.copyWith(customers: updated);

    if (modifiedCustomer != null && state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().saveCustomer(storeId: state.storeId!, customer: modifiedCustomer!);
    }
  }

  /// Membatalkan transaksi rental (khusus Owner)
  /// Mengubah status menjadi dibatalkan dan mengembalikan stok yang disewa
  bool cancelRental(String rentalId) {
    _verifyOwnerAuthorization();
    final rentalIndex = state.rentals.indexWhere((r) => r.id == rentalId);
    if (rentalIndex < 0) return false;

    final targetRental = state.rentals[rentalIndex];
    if (targetRental.status == RentalStatus.selesai || targetRental.status == RentalStatus.dibatalkan) {
      return false; // Transaksi sudah selesai atau sudah pernah dibatalkan
    }

    // 1. Kembalikan stok item yang sebelumnya dipinjam
    final updatedGlobalItems = List<ItemModel>.from(state.items);
    for (final itm in targetRental.items) {
      final gIndex = updatedGlobalItems.indexWhere((g) => g.id == itm.itemId);
      if (gIndex >= 0) {
        final g = updatedGlobalItems[gIndex];
        int newRented = g.rentedStock - itm.qty;
        if (newRented < 0) newRented = 0;
        List<ProductVariantModel> updatedVariants = List.from(g.variants);

        if (g.hasVariants && itm.selectedSize != null) {
          final vIdx = updatedVariants.indexWhere((v) => v.size == itm.selectedSize);
          if (vIdx >= 0) {
            final v = updatedVariants[vIdx];
            int vRented = v.rentedStock - itm.qty;
            if (vRented < 0) vRented = 0;
            updatedVariants[vIdx] = v.copyWith(rentedStock: vRented);
          }
          newRented = updatedVariants.fold(0, (sum, v) => sum + v.rentedStock);
        }

        final updatedG = g.copyWith(
          rentedStock: newRented,
          variants: updatedVariants,
        );
        updatedGlobalItems[gIndex] = updatedG;

        if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
          SupabaseService().saveItem(storeId: state.storeId!, item: updatedG);
        }
      }
    }

    // 2. Update status rental menjadi dibatalkan
    final cancelledRental = targetRental.copyWith(status: RentalStatus.dibatalkan);
    final updatedRentals = List<RentalModel>.from(state.rentals);
    updatedRentals[rentalIndex] = cancelledRental;

    state = state.copyWith(
      items: updatedGlobalItems,
      rentals: updatedRentals,
    );

    // 3. Sinkronisasi status rental ke Supabase
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      SupabaseService().cancelRental(
        rentalId,
        invoiceNumber: targetRental.rentalNumber,
      );
    }

    return true;
  }

  // Printer Settings
  void updatePrinterConfig(PrinterConfigModel newConfig) {
    state = state.copyWith(printerConfig: newConfig);
  }

  // Cashier Account Management (1 Kasir per Toko)
  bool addCashier({required String name, required String email, String? id}) {
    if (state.settings.cashiers.isNotEmpty) {
      return false; // Toko sudah memiliki 1 kasir aktif
    }

    final newCashier = CashierAccountModel(
      id: id ?? 'cashier_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      isActive: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      settings: state.settings.copyWith(cashiers: [newCashier]),
    );
    return true;
  }

  void removeCashier(String cashierId) {
    state = state.copyWith(
      settings: state.settings.copyWith(cashiers: const []),
    );
    if (state.networkStatus == NetworkStatus.online && cashierId.length >= 30) {
      SupabaseService().deleteCashierAccount(cashierId: cashierId);
    }
  }

  bool toggleCashierStatus(String cashierId) {
    if (state.settings.cashiers.isEmpty) return false;
    final currentCashier = state.settings.cashiers.first;
    final updated = currentCashier.copyWith(isActive: !currentCashier.isActive);
    state = state.copyWith(
      settings: state.settings.copyWith(cashiers: [updated]),
    );
    return true;
  }

  Future<void> updateStoreSettings(StoreSettingsModel newSettings, {int? lateFeePerDay}) async {
    state = state.copyWith(
      settings: newSettings,
      storeName: newSettings.storeName,
    );
    if (state.storeId != null && state.networkStatus == NetworkStatus.online) {
      await SupabaseService().updateStoreSettings(
        storeId: state.storeId!,
        settings: newSettings,
        lateFeePerDay: lateFeePerDay,
      );
    }
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppStateData>((ref) {
  return AppStateNotifier();
});
