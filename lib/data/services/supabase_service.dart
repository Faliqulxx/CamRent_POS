import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camprent_pos/core/config/supabase_config.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================================
  // STORE & PROFILES
  // ==========================================================================

  Future<StoreSettingsModel?> fetchStoreSettings(String storeId) async {
    try {
      final res = await _supabase.from('stores').select().eq('id', storeId).maybeSingle();
      if (res == null) return null;

      return StoreSettingsModel(
        storeId: storeId,
        storeName: res['name'] ?? 'CampRent POS',
        subHeader: 'Persewaan Alat Camping & Outdoor',
        storeAddress: res['address'] ?? '',
        storePhone: res['phone'] ?? '',
        receiptFooter: res['receipt_footer_note'] ?? 'Terima kasih atas kunjungan Anda.',
        minDpPercent: (res['min_dp_percent'] as num?)?.toInt() ?? 30,
        lateGracePeriodDays: (res['late_grace_period_days'] as num?)?.toInt() ?? 0,
        defaultDepositAmount: (res['default_deposit_amount'] as num?)?.toInt() ?? 50000,
        minDepositAmount: (res['min_deposit_amount'] as num?)?.toInt() ?? 0,
        isPremium: res['is_premium'] == true,
      );
    } catch (e) {
      developer.log('Error fetching store settings: $e');
      return null;
    }
  }

  Future<bool> updateStoreSettings({
    required String storeId,
    required StoreSettingsModel settings,
    int? lateFeePerDay,
  }) async {
    try {
      await _supabase.from('stores').update({
        'name': settings.storeName,
        'address': settings.storeAddress,
        'phone': settings.storePhone,
        'receipt_footer_note': settings.receiptFooter,
        'min_dp_percent': settings.minDpPercent,
        if (lateFeePerDay != null) 'late_fee_per_day': lateFeePerDay,
        'late_grace_period_days': settings.lateGracePeriodDays,
        'default_deposit_amount': settings.defaultDepositAmount,
        'min_deposit_amount': settings.minDepositAmount,
      }).eq('id', storeId);
      return true;
    } catch (e) {
      developer.log('Error updating store settings: $e');
      return false;
    }
  }

  Future<List<CashierAccountModel>> fetchCashiers(String storeId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('store_id', storeId)
          .eq('role', 'cashier')
          .order('created_at', ascending: true);

      final list = (data as List).map((row) {
        return CashierAccountModel(
          id: row['id'].toString(),
          name: row['name']?.toString() ?? 'Kasir',
          email: row['email']?.toString() ?? '',
          isActive: row['is_active'] == true,
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();

      return list;
    } catch (e) {
      developer.log('Error fetching cashiers: $e');
      return [];
    }
  }

  Future<void> updateCashierProfile({
    required String cashierId,
    required String name,
    required String email,
  }) async {
    try {
      await _supabase.from('profiles').update({
        'name': name,
        'email': email,
      }).eq('id', cashierId);
    } catch (e) {
      developer.log('Error updating cashier profile: $e');
    }
  }

  Future<bool> deleteCashierAccount({required String cashierId}) async {
    try {
      try {
        await _supabase.rpc('delete_cashier_account', params: {'p_cashier_id': cashierId});
      } catch (_) {}
      await _supabase.from('profiles').delete().eq('id', cashierId);
      return true;
    } catch (e) {
      developer.log('Error deleting cashier profile: $e');
      return false;
    }
  }

  /// Pendaftaran / pembaruan kredensial akun kasir oleh Owner toko
  Future<Map<String, dynamic>> createOrUpdateCashierAccount({
    required String storeId,
    required String name,
    required String email,
    required String password,
    String? existingCashierId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanPass = password.trim();

    // 1. Coba panggil RPC PostgreSQL set_cashier_credentials
    try {
      final rpcRes = await _supabase.rpc('set_cashier_credentials', params: {
        'p_store_id': storeId,
        'p_name': cleanName,
        'p_email': cleanEmail,
        'p_password': cleanPass,
      });

      if (rpcRes != null) {
        final Map<String, dynamic> data = rpcRes is Map<String, dynamic>
            ? rpcRes
            : Map<String, dynamic>.from(rpcRes as Map);
        if (data['success'] == true) {
          final userId = data['user_id']?.toString() ?? existingCashierId ?? '';
          return {
            'success': true,
            'id': userId,
            'message': 'Akun kasir berhasil didaftarkan.',
          };
        }
      }
    } catch (rpcErr) {
      developer.log('RPC set_cashier_credentials not available / error: $rpcErr');
    }

    // 2. Fallback: Standalone SupabaseClient (agar tidak menimpa sesi login Owner aktif)
    try {
      String? targetUserId = existingCashierId;
      final isNewId = targetUserId == null ||
          targetUserId.startsWith('cashier_') ||
          targetUserId.length < 30;

      if (isNewId) {
        AuthResponse? authRes;
        if (cleanPass.length < 6) {
          return {
            'success': false,
            'message': 'Kata sandi minimal 6 karakter untuk akun kasir baru.',
          };
        }

        final isolatedClient = SupabaseClient(
          SupabaseConfig.url,
          SupabaseConfig.anonKey,
        );

        authRes = await isolatedClient.auth.signUp(
          email: cleanEmail,
          password: cleanPass,
          data: {
            'name': cleanName,
            'role': 'cashier',
          },
        );

        // Jika email sudah pernah terdaftar sebelumnya di Supabase Auth,
        // signUp() tidak akan memperbarui password (identities kosong).
        if (authRes.user != null && (authRes.user!.identities?.isEmpty ?? false)) {
          return {
            'success': false,
            'message': 'Email "$cleanEmail" sudah pernah terdaftar di Supabase Auth dan kata sandi tidak dapat ditimpa via registrasi biasa. Silakan jalankan skrip SQL "set_cashier_credentials" di menu SQL Editor Supabase agar Owner dapat mereset/mengganti password kasir.',
          };
        }

        targetUserId = authRes.user?.id;
        if (targetUserId == null) {
          return {
            'success': false,
            'message': 'Gagal mendaftarkan akun kasir ke sistem otentikasi. Pastikan email belum digunakan.',
          };
        }
      } else {
        // Akun sudah ada di profiles. Jika Owner mengisi password baru tapi RPC belum dipasang:
        if (cleanPass.isNotEmpty) {
          return {
            'success': false,
            'message': 'Pembaruan kata sandi akun kasir lama membutuhkan fungsi SQL "set_cashier_credentials" di Supabase. Silakan jalankan query SQL dari backend.md (baris 355-435) pada SQL Editor Supabase Anda.',
          };
        }
      }

      // 3. Simpan atau perbarui profil kasir di tabel profiles
      await _supabase.from('profiles').upsert({
        'id': targetUserId,
        'store_id': storeId,
        'role': 'cashier',
        'name': cleanName,
        'email': cleanEmail,
        'is_active': true,
      });

      return {
        'success': true,
        'id': targetUserId,
        'message': 'Akun kasir berhasil didaftarkan.',
      };
    } catch (e) {
      developer.log('Error creating/updating cashier account: $e');
      String errMsg = 'Gagal menyimpan akun kasir: $e';
      if (e.toString().contains('already registered') || e.toString().contains('User already registered')) {
        errMsg = 'Email kasir ini sudah terdaftar di Supabase Auth. Silakan gunakan email lain atau jalankan fungsi set_cashier_credentials.';
      }
      return {
        'success': false,
        'message': errMsg,
      };
    }
  }

  // ==========================================================================
  // CATEGORIES
  // ==========================================================================

  Future<List<CategoryModel>> seedDefaultCategories(String storeId) async {
    const defaultCats = [
      {'name': 'Tenda & Shelter', 'requires_size': false},
      {'name': 'Tas & Carrier', 'requires_size': false},
      {'name': 'Sepatu Outdoor', 'requires_size': true},
      {'name': 'Sandal', 'requires_size': true},
      {'name': 'Jaket & Outerwear', 'requires_size': true},
      {'name': 'Celana Outdoor', 'requires_size': true},
      {'name': 'Pakaian Outdoor', 'requires_size': true},
      {'name': 'Sarung Tangan', 'requires_size': true},
      {'name': 'Sleeping Gear', 'requires_size': false},
      {'name': 'Camping Furniture', 'requires_size': false},
      {'name': 'Cooking & Dining', 'requires_size': false},
      {'name': 'Penerangan', 'requires_size': false},
      {'name': 'Elektronik Outdoor', 'requires_size': false},
      {'name': 'Survival & Safety', 'requires_size': false},
      {'name': 'Peralatan Pendukung', 'requires_size': false},
    ];

    try {
      final rowsToInsert = defaultCats.map((c) => {
        'store_id': storeId,
        'name': c['name'],
        'requires_size': c['requires_size'],
      }).toList();

      final res = await _supabase.from('categories').insert(rowsToInsert).select();
      return (res as List).map((row) => CategoryModel(
        id: row['id'].toString(),
        name: row['name']?.toString() ?? '',
        requiresSize: row['requires_size'] == true,
      )).toList();
    } catch (e) {
      developer.log('Error seeding default categories: $e');
      return [];
    }
  }

  Future<List<CategoryModel>> fetchCategories(String storeId) async {
    try {
      final data = await _supabase
          .from('categories')
          .select()
          .eq('store_id', storeId)
          .order('name', ascending: true);

      final list = (data as List).map((row) {
        return CategoryModel(
          id: row['id'].toString(),
          name: row['name']?.toString() ?? '',
          requiresSize: row['requires_size'] == true,
        );
      }).toList();

      if (list.isEmpty) {
        // Auto-seed kategori standar ke Supabase untuk toko ini agar mendapat UUID permanen
        final seeded = await seedDefaultCategories(storeId);
        if (seeded.isNotEmpty) return seeded;
      }

      return list;
    } catch (e) {
      developer.log('Error fetching categories: $e');
      return [];
    }
  }

  Future<CategoryModel?> insertCategory({
    required String storeId,
    required String name,
    bool requiresSize = false,
  }) async {
    try {
      final res = await _supabase
          .from('categories')
          .insert({
            'store_id': storeId,
            'name': name.trim(),
            'requires_size': requiresSize,
          })
          .select()
          .single();

      return CategoryModel(
        id: res['id'].toString(),
        name: res['name']?.toString() ?? '',
        requiresSize: res['requires_size'] == true,
      );
    } catch (e) {
      developer.log('Error inserting category: $e');
      return null;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _supabase.from('categories').delete().eq('id', categoryId);
      return true;
    } catch (e) {
      developer.log('Error deleting category: $e');
      return false;
    }
  }

  // ==========================================================================
  // ITEMS & SIZE VARIANTS
  // ==========================================================================

  Future<List<ItemModel>> fetchItems(String storeId) async {
    try {
      final data = await _supabase
          .from('items')
          .select('*, item_size_variants(*)')
          .eq('store_id', storeId)
          .order('name', ascending: true);

      final items = <ItemModel>[];
      for (final row in data as List) {
        final hasSizeVariants = row['has_size_variants'] == true;
        final variantsRaw = hasSizeVariants ? (row['item_size_variants'] as List? ?? []) : [];
        final variants = variantsRaw.map((v) {
          final total = (v['total_stock'] as num?)?.toInt() ?? 0;
          final avail = (v['available_stock'] as num?)?.toInt() ?? total;
          final rented = (v['rented_stock'] as num?)?.toInt() ?? (total - avail > 0 ? total - avail : 0);
          final variantPrice = (v['daily_price'] as num?)?.toInt();
          return ProductVariantModel(
            id: v['id'].toString(),
            size: v['size'].toString(),
            stock: total,
            rentedStock: rented,
            damagedStock: 0,
            dailyPrice: variantPrice,
          );
        }).toList();

        final totalStock = (row['total_stock'] as num?)?.toInt() ?? 0;
        final availStock = (row['available_stock'] as num?)?.toInt() ?? totalStock;
        final rentedStock = (row['rented_stock'] as num?)?.toInt() ?? (totalStock - availStock > 0 ? totalStock - availStock : 0);

        final durationRulesRaw = row['duration_pricing'] as List? ?? [];
        final durationPricing = durationRulesRaw.map((dr) {
          if (dr is Map<String, dynamic>) {
            return DurationPriceRule.fromJson(dr);
          } else if (dr is Map) {
            return DurationPriceRule.fromJson(Map<String, dynamic>.from(dr));
          }
          return null;
        }).whereType<DurationPriceRule>().toList();

        final dailyPrice = (row['daily_price'] as num?)?.toInt() ?? 0;
        final replacementPrice = (row['replacement_price'] as num?)?.toInt() ?? (dailyPrice * 10);

        int? priceTwoOrMore;
        if (row['price_two_or_more_days'] != null && (row['price_two_or_more_days'] as num).toInt() > 0) {
          priceTwoOrMore = (row['price_two_or_more_days'] as num).toInt();
        } else {
          final r2 = durationPricing.where((r) => r.days >= 2 && r.pricePerDay > 0).toList();
          if (r2.isNotEmpty) {
            r2.sort((a, b) => a.days.compareTo(b.days));
            priceTwoOrMore = r2.first.pricePerDay;
          }
        }
        final finalPriceTwoOrMore = (priceTwoOrMore != null && priceTwoOrMore > 0)
            ? priceTwoOrMore
            : dailyPrice;

        items.add(
          ItemModel(
            id: row['id'].toString(),
            categoryId: row['category_id']?.toString() ?? 'cat_all',
            name: row['name']?.toString() ?? '',
            dailyPrice: dailyPrice,
            priceTwoOrMoreDays: finalPriceTwoOrMore,
            replacementPrice: replacementPrice,
            totalStock: totalStock,
            rentedStock: rentedStock,
            damagedStock: 0,
            description: row['description']?.toString() ?? '',
            isActive: true,
            variants: variants,
            durationPricing: [
              DurationPriceRule(days: 1, pricePerDay: dailyPrice, isActive: true),
              DurationPriceRule(days: 2, pricePerDay: finalPriceTwoOrMore, isActive: true),
            ],
          ),
        );
      }
      return items;
    } catch (e) {
      developer.log('Error fetching items: $e');
      return [];
    }
  }

  static bool _isValidUuid(String? id) {
    if (id == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  }

  Future<String?> saveItem({
    required String storeId,
    required ItemModel item,
  }) async {
    try {
      // Pastikan category_id valid UUID atau null agar PostgreSQL tidak crash 22P02 invalid UUID syntax
      String? categoryId;
      if (item.categoryId != 'cat_all' && _isValidUuid(item.categoryId)) {
        categoryId = item.categoryId;
      }

      final price2Plus = item.effectivePriceTwoOrMoreDays > 0 ? item.effectivePriceTwoOrMoreDays : item.dailyPrice;
      final itemPayload = {
        'store_id': storeId,
        'category_id': categoryId,
        'name': item.name,
        'daily_price': item.dailyPrice,
        'price_two_or_more_days': price2Plus,
        'replacement_price': item.replacementPrice,
        'total_stock': item.totalStock,
        'available_stock': item.availableStock,
        'rented_stock': item.rentedStock,
        'has_size_variants': item.hasVariants,
        'duration_pricing': [
          {'days': 1, 'price_per_day': item.dailyPrice, 'is_active': true, 'is_premium': false},
          {'days': 2, 'price_per_day': price2Plus, 'is_active': true, 'is_premium': false},
        ],
        'description': item.description,
      };

      final hasValidUuid = _isValidUuid(item.id);
      Map<String, dynamic> finalPayload = Map.from(itemPayload);
      dynamic res;
      try {
        res = await _supabase.from('items').upsert({
          if (hasValidUuid) 'id': item.id,
          ...finalPayload,
        }).select().single();
      } catch (upsertErr) {
        // Jika kolom price_two_or_more_days belum ada di Supabase, fallback tanpa kolom tersebut
        if (upsertErr.toString().contains('price_two_or_more_days')) {
          finalPayload.remove('price_two_or_more_days');
          res = await _supabase.from('items').upsert({
            if (hasValidUuid) 'id': item.id,
            ...finalPayload,
          }).select().single();
        } else {
          rethrow;
        }
      }

      final itemId = res['id']?.toString();

      if (item.hasVariants && itemId != null) {
        for (final v in item.variants) {
          await _supabase.from('item_size_variants').upsert({
            if (_isValidUuid(v.id)) 'id': v.id,
            'item_id': itemId,
            'size': v.size,
            'total_stock': v.stock,
            'available_stock': v.availableStock,
            'rented_stock': v.rentedStock,
            'daily_price': v.dailyPrice,
          });
        }
      } else if (!item.hasVariants && itemId != null && _isValidUuid(itemId)) {
        try {
          await _supabase.from('item_size_variants').delete().eq('item_id', itemId);
        } catch (_) {}
      }
      return itemId;
    } catch (e) {
      developer.log('Error saving item: $e');
      return null;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    try {
      if (_isValidUuid(itemId)) {
        await _supabase.from('item_size_variants').delete().eq('item_id', itemId);
        await _supabase.from('items').delete().eq('id', itemId);
      }
      return true;
    } catch (e) {
      developer.log('Error deleting item: $e');
      return false;
    }
  }

  // ==========================================================================
  // CUSTOMERS
  // ==========================================================================

  Future<List<CustomerModel>> fetchCustomers(String storeId) async {
    try {
      final data = await _supabase
          .from('customers')
          .select()
          .eq('store_id', storeId)
          .order('name', ascending: true);

      return (data as List).map((row) {
        return CustomerModel(
          id: row['id'].toString(),
          name: row['name']?.toString() ?? '',
          phone: row['phone']?.toString() ?? '',
          address: row['address']?.toString() ?? '',
          note: row['nik']?.toString() ?? '',
          isBlacklisted: row['is_blacklisted'] == true,
          blacklistReason: row['blacklist_reason']?.toString(),
          totalRentals: 0,
        );
      }).toList();
    } catch (e) {
      developer.log('Error fetching customers: $e');
      return [];
    }
  }

  Future<String?> saveCustomer({
    required String storeId,
    required CustomerModel customer,
  }) async {
    try {
      final res = await _supabase.from('customers').upsert({
        if (!customer.id.startsWith('cust_') && customer.id.length >= 30) 'id': customer.id,
        'store_id': storeId,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'is_blacklisted': customer.isBlacklisted,
        'blacklist_reason': customer.blacklistReason,
      }).select().single();

      return res['id']?.toString();
    } catch (e) {
      developer.log('Error saving customer: $e');
      return null;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    try {
      if (_isValidUuid(customerId)) {
        await _supabase.from('customers').delete().eq('id', customerId);
      }
      return true;
    } catch (e) {
      developer.log('Error deleting customer: $e');
      return false;
    }
  }

  // ==========================================================================
  // RENTALS
  // ==========================================================================

  Future<List<RentalModel>> fetchRentals(String storeId) async {
    try {
      final data = await _supabase
          .from('rentals')
          .select('*, rental_items(*)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      final result = <RentalModel>[];
      for (final row in data as List) {
        final itemsRaw = row['rental_items'] as List? ?? [];
        final items = itemsRaw.map((ri) {
          return RentalItemModel(
            id: ri['id'].toString(),
            itemId: ri['item_id']?.toString() ?? '',
            nameSnapshot: ri['item_name']?.toString() ?? '',
            selectedSize: ri['size']?.toString(),
            priceSnapshot: (ri['price_per_day'] as num?)?.toInt() ?? 0,
            replacementPriceSnapshot: ((ri['price_per_day'] as num?)?.toInt() ?? 0) * 10,
            qty: (ri['qty'] as num?)?.toInt() ?? 1,
            condition: ItemCondition.baik,
          );
        }).toList();

        final rentalStatusStr = row['rental_status']?.toString() ?? 'active';
        RentalStatus status = RentalStatus.aktif;
        if (rentalStatusStr == 'completed') {
          status = RentalStatus.selesai;
        } else if (rentalStatusStr == 'cancelled') {
          status = RentalStatus.dibatalkan;
        }

        final payMethodStr = row['payment_method']?.toString() ?? 'cash';
        PaymentMethod payMethod = PaymentMethod.tunai;
        if (payMethodStr == 'transfer') {
          payMethod = PaymentMethod.transfer;
        } else if (payMethodStr == 'qris') {
          payMethod = PaymentMethod.qris;
        }

        final collatTypeStr = row['guarantee_type']?.toString() ?? 'ktp';
        CollateralType collat = CollateralType.ktp;
        if (collatTypeStr == 'sim') collat = CollateralType.sim;
        if (collatTypeStr == 'ktm') collat = CollateralType.ktm;
        if (collatTypeStr == 'paspor') collat = CollateralType.paspor;

        final depositAmt = (row['deposit_amount'] as num?)?.toInt() ?? 0;
        final hasDeposit = depositAmt > 0;

        final durationDays = (row['total_days'] as num?)?.toInt() ?? 1;
        final subtotal = (row['subtotal'] as num?)?.toInt() ?? 0;
        final discount = (row['discount'] as num?)?.toInt() ?? 0;
        final totalAmount = (row['total_amount'] as num?)?.toInt() ?? subtotal;
        final paidAmount = (row['paid_amount'] as num?)?.toInt() ?? 0;
        final lateFee = (row['late_fee'] as num?)?.toInt() ?? 0;
        final damageFee = (row['damage_fee'] as num?)?.toInt() ?? 0;

        final List<RentalFeeItem> feeList = [];
        if (lateFee > 0) {
          feeList.add(RentalFeeItem(id: 'fee_telat_${row['id']}', name: 'Denda Keterlambatan', amount: lateFee, type: 'telat'));
        }
        if (damageFee > 0) {
          feeList.add(RentalFeeItem(id: 'fee_rusak_${row['id']}', name: 'Biaya Kerusakan / Kehilangan', amount: damageFee, type: 'rusak'));
        }

        result.add(
          RentalModel(
            id: row['id'].toString(),
            rentalNumber: row['invoice_number']?.toString() ?? '',
            customer: CustomerModel(
              id: row['customer_id']?.toString() ?? '',
              name: row['customer_name']?.toString() ?? '',
              phone: row['customer_phone']?.toString() ?? '',
            ),
            cashierName: 'Kasir',
            pickupDate: DateTime.tryParse(row['start_date']?.toString() ?? '') ?? DateTime.now(),
            scheduledReturnDate: DateTime.tryParse(row['end_date']?.toString() ?? '') ?? DateTime.now(),
            durationDays: durationDays,
            subtotal: subtotal,
            discount: discount,
            totalSewa: totalAmount,
            dpPaid: paidAmount,
            status: status,
            items: items,
            fees: feeList,
            collateral: !hasDeposit
                ? CollateralModel(
                    type: collat,
                    note: row['guarantee_number']?.toString() ?? '',
                  )
                : null,
            deposit: hasDeposit
                ? DepositModel(
                    amount: depositAmt,
                  )
                : null,
            payments: [
              PaymentRecord(
                id: 'pay_${row['id']}',
                type: PaymentType.dp,
                method: payMethod,
                amount: paidAmount,
                time: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
                cashierName: 'Kasir',
              ),
            ],
          ),
        );
      }
      return result;
    } catch (e) {
      developer.log('Error fetching rentals: $e');
      return [];
    }
  }

  Future<String?> createRental({
    required String storeId,
    required RentalModel rental,
    String? shiftId,
  }) async {
    try {
      final payMethod = rental.payments.isNotEmpty ? rental.payments.first.method : PaymentMethod.tunai;
      final payMethodStr = payMethod == PaymentMethod.tunai
          ? 'cash'
          : payMethod == PaymentMethod.transfer
              ? 'transfer'
              : 'qris';

      final remaining = rental.remainingRentalFee;
      final payStatusStr = remaining <= 0 ? 'paid' : (rental.dpPaid > 0 ? 'dp' : 'unpaid');
      final rentStatusStr = rental.status == RentalStatus.selesai
          ? 'completed'
          : rental.status == RentalStatus.dibatalkan
              ? 'cancelled'
              : 'active';

      final guaranteeType = rental.collateral?.type.name;
      final guaranteeNote = rental.collateral?.note;
      final depositAmt = rental.deposit?.amount ?? 0;

      final rentalData = {
        'store_id': storeId,
        if (shiftId != null && _isValidUuid(shiftId)) 'shift_id': shiftId,
        'invoice_number': rental.rentalNumber,
        if (_isValidUuid(rental.customer.id)) 'customer_id': rental.customer.id,
        'customer_name': rental.customer.name,
        'customer_phone': rental.customer.phone,
        'start_date': rental.pickupDate.toIso8601String().split('T').first,
        'end_date': rental.scheduledReturnDate.toIso8601String().split('T').first,
        'total_days': rental.durationDays,
        'subtotal': rental.subtotal,
        'discount': rental.discount,
        'total_amount': rental.totalSewa,
        'paid_amount': rental.dpPaid,
        'remaining_balance': remaining,
        'payment_method': payMethodStr,
        'payment_status': payStatusStr,
        'rental_status': rentStatusStr,
        'guarantee_type': guaranteeType,
        'guarantee_number': guaranteeNote,
        'deposit_amount': depositAmt,
        'late_days': rental.overdueDays,
        'late_fee': rental.totalFees,
        'damage_fee': 0,
      };

      final res = await _supabase.from('rentals').insert(rentalData).select().single();
      final rentalId = res['id']?.toString();

      // Insert rental items & sinkronisasi stok sewa ke Supabase
      if (rentalId != null) {
        for (final item in rental.items) {
          await _supabase.from('rental_items').insert({
            'rental_id': rentalId,
            if (_isValidUuid(item.itemId)) 'item_id': item.itemId,
            'item_name': item.nameSnapshot,
            'size': item.selectedSize,
            'qty': item.qty,
            'price_per_day': item.priceSnapshot,
            'subtotal': item.subtotal,
            'condition_on_return': item.condition == ItemCondition.baik
                ? 'good'
                : item.condition == ItemCondition.rusak
                    ? 'damaged'
                    : 'dirty',
          });

          // Update rented_stock & available_stock di tabel items Supabase
          if (_isValidUuid(item.itemId)) {
            try {
              final itemRow = await _supabase
                  .from('items')
                  .select('total_stock, available_stock, rented_stock')
                  .eq('id', item.itemId)
                  .maybeSingle();

              if (itemRow != null) {
                final total = (itemRow['total_stock'] as num?)?.toInt() ?? 0;
                final currentRented = (itemRow['rented_stock'] as num?)?.toInt() ?? 0;
                final newRented = currentRented + item.qty;
                final newAvail = (total - newRented) > 0 ? (total - newRented) : 0;
                await _supabase.from('items').update({
                  'rented_stock': newRented,
                  'available_stock': newAvail,
                }).eq('id', item.itemId);
              }
            } catch (stkErr) {
              developer.log('Error updating rented stock in Supabase: $stkErr');
            }
          }
        }
      }

      return rentalId;
    } catch (e) {
      developer.log('Error creating rental: $e');
      return null;
    }
  }

  Future<bool> updateRentalStatus({
    required String rentalId,
    String? invoiceNumber,
    required RentalStatus status,
    int? paidAmount,
    int? lateFee,
    int? damageFee,
  }) async {
    try {
      final statusStr = status == RentalStatus.selesai
          ? 'completed'
          : status == RentalStatus.dibatalkan
              ? 'cancelled'
              : 'active';

      final updatePayload = {
        'rental_status': statusStr,
        if (paidAmount != null) 'paid_amount': paidAmount,
        if (paidAmount != null) 'remaining_balance': 0,
        if (paidAmount != null) 'payment_status': 'paid',
        if (lateFee != null) 'late_fee': lateFee,
        if (damageFee != null) 'damage_fee': damageFee,
      };

      if (_isValidUuid(rentalId)) {
        await _supabase.from('rentals').update(updatePayload).eq('id', rentalId);
      } else if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
        await _supabase.from('rentals').update(updatePayload).eq('invoice_number', invoiceNumber);
      } else {
        await _supabase.from('rentals').update(updatePayload).eq('id', rentalId);
      }
      return true;
    } catch (e) {
      developer.log('Error updating rental: $e');
      return false;
    }
  }

  Future<bool> cancelRental(String rentalId, {String? invoiceNumber}) async {
    try {
      if (_isValidUuid(rentalId)) {
        await _supabase.from('rentals').update({
          'rental_status': 'cancelled',
        }).eq('id', rentalId);
      } else if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
        await _supabase.from('rentals').update({
          'rental_status': 'cancelled',
        }).eq('invoice_number', invoiceNumber);
      } else {
        await _supabase.from('rentals').update({
          'rental_status': 'cancelled',
        }).eq('id', rentalId);
      }
      return true;
    } catch (e) {
      developer.log('Error cancelling rental: $e');
      return false;
    }
  }

  // ==========================================================================
  // SHIFTS
  // ==========================================================================

  Future<List<CashierShiftModel>> fetchShifts(String storeId) async {
    try {
      final data = await _supabase
          .from('shifts')
          .select()
          .eq('store_id', storeId)
          .order('start_time', ascending: false);

      return (data as List).map((row) {
        final statusStr = row['status']?.toString() ?? 'open';
        return CashierShiftModel(
          id: row['id'].toString(),
          cashierId: row['cashier_id']?.toString() ?? '',
          cashierName: row['cashier_name']?.toString() ?? '',
          cashierEmail: '',
          date: DateTime.tryParse(row['start_time']?.toString() ?? '') ?? DateTime.now(),
          startTime: DateTime.tryParse(row['start_time']?.toString() ?? '') ?? DateTime.now(),
          endTime: row['end_time'] != null ? DateTime.tryParse(row['end_time']) : null,
          initialCash: (row['initial_cash'] as num?)?.toInt() ?? 0,
          totalTransactions: 0,
          totalCashPayments: (row['total_sales_cash'] as num?)?.toInt() ?? 0,
          totalTransferPayments: (row['total_sales_transfer'] as num?)?.toInt() ?? 0,
          totalQrisPayments: (row['total_sales_qris'] as num?)?.toInt() ?? 0,
          actualCash: (row['actual_cash'] as num?)?.toInt(),
          discrepancyNote: row['notes']?.toString(),
          status: statusStr == 'closed' ? ShiftStatus.selesai : ShiftStatus.sedangBerjalan,
        );
      }).toList();
    } catch (e) {
      developer.log('Error fetching shifts: $e');
      return [];
    }
  }

  Future<String?> openShift({
    required String storeId,
    required String cashierName,
    required int initialCash,
    String? cashierId,
  }) async {
    try {
      // 1. Tutup shift aktif sebelumnya untuk kasir ini jika ada yang belum ditutup
      try {
        await _supabase
            .from('shifts')
            .update({
              'end_time': DateTime.now().toIso8601String(),
              'status': 'closed',
              'notes': 'Ditutup otomatis karena kasir membuka shift baru.',
            })
            .eq('store_id', storeId)
            .eq('cashier_name', cashierName)
            .eq('status', 'open');
      } catch (closeErr) {
        developer.log('Non-critical: error closing previous shifts: $closeErr');
      }

      // 2. Buat shift baru
      final res = await _supabase
          .from('shifts')
          .insert({
            'store_id': storeId,
            if (cashierId != null && cashierId.length >= 30) 'cashier_id': cashierId,
            'cashier_name': cashierName,
            'initial_cash': initialCash,
            'status': 'open',
          })
          .select()
          .single();

      return res['id']?.toString();
    } catch (e) {
      developer.log('Error opening shift: $e');
      return null;
    }
  }

  Future<bool> closeShift({
    required String shiftId,
    required int actualCash,
    required int expectedCash,
    required int totalCash,
    required int totalTransfer,
    required int totalQris,
    String? notes,
    String? storeId,
    String? cashierName,
  }) async {
    try {
      final diff = actualCash - expectedCash;
      final updateData = {
        'end_time': DateTime.now().toIso8601String(),
        'actual_cash': actualCash,
        'expected_cash': expectedCash,
        'difference': diff,
        'total_sales_cash': totalCash,
        'total_sales_transfer': totalTransfer,
        'total_sales_qris': totalQris,
        'status': 'closed',
        'notes': notes,
      };

      if (_isValidUuid(shiftId)) {
        await _supabase.from('shifts').update(updateData).eq('id', shiftId);
        return true;
      } else if (storeId != null && cashierName != null && cashierName.isNotEmpty) {
        // Fallback jika ID lokal bukan valid UUID (misal shf_...):
        // Update baris shift yang statusnya masih 'open' milik kasir ini di toko
        await _supabase
            .from('shifts')
            .update(updateData)
            .eq('store_id', storeId)
            .eq('cashier_name', cashierName)
            .eq('status', 'open');
        return true;
      } else {
        developer.log('closeShift: invalid UUID $shiftId and no storeId/cashierName fallback');
        return false;
      }
    } catch (e) {
      developer.log('Error closing shift: $e');
      return false;
    }
  }
}
