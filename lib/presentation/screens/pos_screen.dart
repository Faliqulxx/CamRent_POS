import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/cart_bottom_sheet.dart';
import 'package:camprent_pos/presentation/widgets/close_shift_dialog.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final form = appState.newRentalForm;

    // Filter produk aktif berdasarkan kategori & pencarian (Read-Only POS)
    final filteredItems = appState.items.where((it) {
      if (!it.isActive) return false;
      final matchCategory = appState.selectedCategoryId == 'cat_all' || it.categoryId == appState.selectedCategoryId;
      final q = appState.itemSearchQuery.toLowerCase().trim();
      final matchSearch = q.isEmpty ||
          it.name.toLowerCase().contains(q) ||
          it.description.toLowerCase().contains(q) ||
          it.variants.any((v) => v.size.toLowerCase().contains(q));
      return matchCategory && matchSearch;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 540;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Active Cashier Shift Banner (PRD Shift Kasir)
          if (appState.activeCashierShift != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                border: Border(bottom: BorderSide(color: Color(0xFFBBF7D0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shift Aktif: ${appState.activeCashierShift!.cashierName} • Modal: ${CurrencyFormatter.format(appState.activeCashierShift!.initialCash)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.lock_clock_outlined, size: 14),
                    label: const Text('Tutup Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => CloseShiftDialog.show(context),
                  ),
                ],
              ),
            ),

          // Search & Category Chips (Clean, text-only, no emojis)
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 12, isMobile ? 12 : 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk rental atau ukuran...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                    suffixIcon: appState.itemSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => ref.read(appStateProvider.notifier).setItemSearch(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  onChanged: (val) => ref.read(appStateProvider.notifier).setItemSearch(val),
                ),
                const SizedBox(height: 10),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: appState.categories.map((cat) {
                      final isSel = appState.selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: isSel,
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onSelected: (_) {
                            ref.read(appStateProvider.notifier).setCategory(cat.id);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Items Grid
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 44, color: AppColors.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'Produk tidak ditemukan',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Pilih kategori Semua atau gunakan kata kunci lain.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Di mobile: selalu 2 kolom (kiri & kanan)
                      final crossAxisCount = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                              ? 3
                              : 2;

                      final childAspectRatio = crossAxisCount >= 4
                          ? 1.25
                          : crossAxisCount == 3
                              ? 1.2
                              : constraints.maxWidth < 360
                                  ? 0.98
                                  : constraints.maxWidth < 420
                                      ? 1.05
                                      : 1.15;

                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(isMobile ? 10 : 16, 12, isMobile ? 10 : 16, 90),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: isMobile ? 10 : 12,
                          mainAxisSpacing: isMobile ? 10 : 12,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = filteredItems[idx];
                          return _PosProductCard(item: item);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      // Bottom Floating Cart Bar
      bottomSheet: form.cartItems.isNotEmpty
          ? Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${form.cartItems.fold(0, (sum, ci) => sum + ci.qty)} Produk Dipilih • ${form.durationDays} Hari',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          CurrencyFormatter.format(form.totals.totalSewa),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => CartBottomSheet.show(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Lanjut Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _PosProductCard extends ConsumerWidget {
  final ItemModel item;

  const _PosProductCard({required this.item});

  void _showVariantSelectorModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final appState = ref.watch(appStateProvider);
            final cartItems = appState.newRentalForm.cartItems;

            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${CurrencyFormatter.format(item.dailyPrice)} / hari',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PILIH UKURAN:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: item.variants.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final v = item.variants[i];
                      final cartMatch = cartItems.where((ci) => ci.item.id == item.id && ci.selectedSize == v.size).firstOrNull;
                      final currentQty = cartMatch?.qty ?? 0;
                      final isOutOfStock = v.availableStock <= 0;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ukuran ${v.size}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  isOutOfStock ? 'Stok habis' : 'Tersedia ${v.availableStock} unit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOutOfStock ? AppColors.danger : AppColors.textSecondary,
                                    fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentQty == 0)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOutOfStock ? Colors.grey.shade300 : AppColors.primary,
                                foregroundColor: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: isOutOfStock
                                  ? null
                                  : () {
                                      ref.read(appStateProvider.notifier).addItemToCart(item, selectedSize: v.size);
                                    },
                              child: const Text('Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          else
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.textSecondary),
                                  onPressed: () {
                                    ref.read(appStateProvider.notifier).updateCartItemQty(
                                          item.id,
                                          currentQty - 1,
                                          selectedSize: v.size,
                                        );
                                  },
                                ),
                                Text(
                                  '$currentQty',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                                  onPressed: currentQty >= v.availableStock
                                      ? null
                                      : () {
                                          ref.read(appStateProvider.notifier).updateCartItemQty(
                                                item.id,
                                                currentQty + 1,
                                                selectedSize: v.size,
                                              );
                                        },
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final cartItems = appState.newRentalForm.cartItems;
    final cat = appState.categories.firstWhere(
      (c) => c.id == item.categoryId,
      orElse: () => const CategoryModel(id: '', name: 'Lainnya'),
    );

    final isOutOfStock = item.isOutOfStock;

    // Hitung berapa unit produk ini di keranjang
    final inCartUnits = cartItems.where((ci) => ci.item.id == item.id).fold(0, (sum, ci) => sum + ci.qty);

    final isMobile = MediaQuery.of(context).size.width < 520;

    // Harga Sewa (menyesuaikan durasi sewa yang dipilih di POS jika ada aturan berjenjang)
    final durationDays = appState.newRentalForm.durationDays;
    final currentDurationPrice = item.getPriceForDuration(durationDays, isStorePremium: appState.isStorePremium);
    final hasSpecialDurationRate = durationDays > 1 && currentDurationPrice != item.dailyPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inCartUnits > 0 ? AppColors.primary : AppColors.border,
          width: inCartUnits > 0 ? 1.5 : 1,
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama & Kategori
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.name,
                      style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (inCartUnits > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMobile ? '$inCartUnits×' : '$inCartUnits di keranjang',
                    style: TextStyle(color: Colors.white, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),

          const Spacer(),

          // Harga Sewa (menyesuaikan durasi sewa yang dipilih di POS jika ada aturan berjenjang)
          Row(
            children: [
              Text(
                '${CurrencyFormatter.format(currentDurationPrice)} / hari',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
              ),
              if (hasSpecialDurationRate) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Tarif $durationDays hr',
                    style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Varian Ukuran atau Stok
          if (item.hasVariants) ...[
            Text(
              'Ukuran: ${item.sizesSummary}',
              style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: isMobile ? 30 : 32,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showVariantSelectorModal(context, ref),
                child: Text('Pilih Ukuran', style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ),
          ] else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Stok: ${item.effectiveTotalStock} • ',
                  style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.textSecondary),
                ),
                Text(
                  isOutOfStock ? 'Habis' : 'Tersedia: ${item.availableStock}',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: isOutOfStock ? AppColors.danger : const Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.effectiveRentedStock > 0)
                  Text(
                    ' (${item.effectiveRentedStock} disewa)',
                    style: TextStyle(fontSize: isMobile ? 9 : 10, color: const Color(0xFFD97706)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Tombol Tambah / Counter untuk produk tanpa ukuran
            SizedBox(
              width: double.infinity,
              height: isMobile ? 30 : 32,
              child: inCartUnits == 0
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey.shade300 : AppColors.primary,
                        foregroundColor: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              ref.read(appStateProvider.notifier).addItemToCart(item);
                            },
                      child: Text(isOutOfStock ? 'Habis' : 'Tambah', style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold)),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              ref.read(appStateProvider.notifier).updateCartItemQty(item.id, inCartUnits - 1);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$inCartUnits',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: inCartUnits >= item.availableStock
                                ? null
                                : () {
                                    ref.read(appStateProvider.notifier).updateCartItemQty(item.id, inCartUnits + 1);
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: inCartUnits >= item.availableStock ? Colors.grey.shade200 : AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add,
                                size: 16,
                                color: inCartUnits >= item.availableStock ? Colors.grey : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
