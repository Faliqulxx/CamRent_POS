import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
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
        storeName: res['name'] ?? 'CampRent POS',
        subHeader: 'Persewaan Alat Camping & Outdoor',
        storeAddress: res['address'] ?? '',
        storePhone: res['phone'] ?? '',
        receiptFooter: res['receipt_footer_note'] ?? 'Terima kasih atas kunjungan Anda.',
        minDpPercent: (res['min_dp_percent'] as num?)?.toInt() ?? 30,
        lateGracePeriodDays: (res['late_grace_period_days'] as num?)?.toInt() ?? 0,
        defaultDepositAmount: (res['default_deposit_amount'] as num?)?.toInt() ?? 50000,
        minDepositAmount: (res['min_deposit_amount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      developer.log('Error fetching store settings: $e');
      return null;
    }
  }

  // ==========================================================================
  // CATEGORIES
  // ==========================================================================

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
        final variantsRaw = row['item_size_variants'] as List? ?? [];
        final variants = variantsRaw.map((v) {
          final total = (v['total_stock'] as num?)?.toInt() ?? 0;
          final avail = (v['available_stock'] as num?)?.toInt() ?? total;
          final rented = total - avail > 0 ? total - avail : 0;
          return ProductVariantModel(
            id: v['id'].toString(),
            size: v['size'].toString(),
            stock: total,
            rentedStock: rented,
            damagedStock: 0,
            dailyPrice: null,
          );
        }).toList();

        final totalStock = (row['total_stock'] as num?)?.toInt() ?? 0;
        final availStock = (row['available_stock'] as num?)?.toInt() ?? totalStock;
        final rentedStock = totalStock - availStock > 0 ? totalStock - availStock : 0;

        items.add(
          ItemModel(
            id: row['id'].toString(),
            categoryId: row['category_id']?.toString() ?? 'cat_all',
            name: row['name']?.toString() ?? '',
            dailyPrice: (row['daily_price'] as num?)?.toInt() ?? 0,
            replacementPrice: ((row['daily_price'] as num?)?.toInt() ?? 0) * 10,
            totalStock: totalStock,
            rentedStock: rentedStock,
            damagedStock: 0,
            isActive: true,
            variants: variants,
          ),
        );
      }
      return items;
    } catch (e) {
      developer.log('Error fetching items: $e');
      return [];
    }
  }

  Future<bool> saveItem({
    required String storeId,
    required ItemModel item,
  }) async {
    try {
      final itemPayload = {
        'store_id': storeId,
        'category_id': item.categoryId == 'cat_all' ? null : item.categoryId,
        'name': item.name,
        'daily_price': item.dailyPrice,
        'total_stock': item.totalStock,
        'available_stock': item.availableStock,
        'has_size_variants': item.hasVariants,
      };

      final res = await _supabase.from('items').upsert({
        if (!item.id.startsWith('itm_temp') && item.id.length >= 30) 'id': item.id,
        ...itemPayload,
      }).select().single();

      final itemId = res['id'];

      if (item.hasVariants) {
        for (final v in item.variants) {
          await _supabase.from('item_size_variants').upsert({
            if (!v.id.startsWith('var_temp') && v.id.length >= 30) 'id': v.id,
            'item_id': itemId,
            'size': v.size,
            'total_stock': v.stock,
            'available_stock': v.availableStock,
          });
        }
      }
      return true;
    } catch (e) {
      developer.log('Error saving item: $e');
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

  Future<bool> createRental({
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
        if (shiftId != null && !shiftId.startsWith('shf_') && shiftId.length >= 30) 'shift_id': shiftId,
        'invoice_number': rental.rentalNumber,
        if (rental.customer.id.length >= 30) 'customer_id': rental.customer.id,
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
      final rentalId = res['id'];

      // Insert rental items
      for (final item in rental.items) {
        await _supabase.from('rental_items').insert({
          'rental_id': rentalId,
          if (item.itemId.length >= 30) 'item_id': item.itemId,
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
      }

      return true;
    } catch (e) {
      developer.log('Error creating rental: $e');
      return false;
    }
  }

  Future<bool> updateRentalStatus({
    required String rentalId,
    required RentalStatus status,
    int? paidAmount,
    int? lateFee,
    int? damageFee,
  }) async {
    try {
      final statusStr = status == RentalStatus.selesai ? 'completed' : 'active';
      await _supabase.from('rentals').update({
        'rental_status': statusStr,
        if (paidAmount != null) 'paid_amount': paidAmount,
        if (paidAmount != null) 'remaining_balance': 0,
        if (paidAmount != null) 'payment_status': 'paid',
        if (lateFee != null) 'late_fee': lateFee,
        if (damageFee != null) 'damage_fee': damageFee,
      }).eq('id', rentalId);
      return true;
    } catch (e) {
      developer.log('Error updating rental: $e');
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
  }) async {
    try {
      final diff = actualCash - expectedCash;
      await _supabase.from('shifts').update({
        'end_time': DateTime.now().toIso8601String(),
        'actual_cash': actualCash,
        'expected_cash': expectedCash,
        'difference': diff,
        'total_sales_cash': totalCash,
        'total_sales_transfer': totalTransfer,
        'total_sales_qris': totalQris,
        'status': 'closed',
        'notes': notes,
      }).eq('id', shiftId);
      return true;
    } catch (e) {
      developer.log('Error closing shift: $e');
      return false;
    }
  }
}
