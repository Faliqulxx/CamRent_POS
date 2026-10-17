import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/item_form_dialog.dart';
import 'package:camprent_pos/presentation/widgets/category_management_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final items = appState.items;
    final isOwner = appState.currentRole == AppRole.admin;

    // Filter produk berdasarkan pencarian
    final filteredItems = items.where((it) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      final cat = appState.categories.firstWhere(
        (c) => c.id == it.categoryId,
        orElse: () => const CategoryModel(id: '', name: 'Lainnya'),
      );
      return it.name.toLowerCase().contains(q) ||
          cat.name.toLowerCase().contains(q) ||
          it.description.toLowerCase().contains(q) ||
          it.variants.any((v) => v.size.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Tambah Produk',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => ItemFormDialog.show(context),
            )
          : null,
      body: Column(
        children: [
          // Banner Role Kasir jika bukan Owner
          if (!isOwner)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Kasir (Read-Only): Anda hanya dapat melihat data produk dan ketersediaan stok.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Header Bar: Search & Action
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari produk, kategori, atau ukuran...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.category_outlined, size: 16),
                    label: const Text('Kelola Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () => CategoryManagementDialog.show(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text(
                      'Tambah Produk',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    onPressed: () => ItemFormDialog.show(context),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Product List
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'Tidak ada produk yang cocok dengan pencarian.',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      return _buildProductCard(context, item, isOwner);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ItemModel item, bool isOwner) {
    final appState = ref.watch(appStateProvider);
    final cat = appState.categories.firstWhere(
      (c) => c.id == item.categoryId,
      orElse: () => const CategoryModel(id: '', name: 'Lainnya'),
    );

    // Format varian ukuran sesuai aturan Aturan 4
    String variantText;
    if (!item.hasVariants) {
      variantText = 'Tidak ada';
    } else {
      final sizeList = item.variants.map((v) => v.size).toList();
      if (sizeList.length <= 4) {
        variantText = sizeList.join('   ');
      } else {
        final firstFour = sizeList.take(4).join(', ');
        final remaining = sizeList.length - 4;
        variantText = '$firstFour +$remaining ukuran';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Nonaktif',
                    style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Harga Sewa & Aturan Durasi Sewa
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${CurrencyFormatter.format(item.dailyPrice)} / 1 hari',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '2+ hari: ${CurrencyFormatter.format(item.effectivePriceTwoOrMoreDays)}/hr',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Varian Ukuran jika ada
          if (item.hasVariants) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Varian Ukuran: ',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Text(
                    variantText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Keterangan Rincian Status Stok Barang (Total vs Tersedia vs Sedang Disewa)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStockInfoBadge(
                  label: 'Total Stok',
                  value: '${item.effectiveTotalStock}',
                  color: AppColors.textPrimary,
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                _buildStockInfoBadge(
                  label: 'Tersedia',
                  value: '${item.availableStock}',
                  color: item.availableStock > 0 ? const Color(0xFF16A34A) : AppColors.danger,
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                _buildStockInfoBadge(
                  label: 'Sedang Disewa',
                  value: '${item.effectiveRentedStock}',
                  color: item.effectiveRentedStock > 0 ? const Color(0xFFD97706) : AppColors.textSecondary,
                ),
                if (item.effectiveDamagedStock > 0) ...[
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  _buildStockInfoBadge(
                    label: 'Rusak',
                    value: '${item.effectiveDamagedStock}',
                    color: AppColors.danger,
                  ),
                ],
              ],
            ),
          ),

          // Detail stok per varian jika ada varian
          if (item.hasVariants) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: item.variants.map((v) {
                  return Text(
                    '${v.size}: ${v.availableStock}/${v.stock} unit (${v.rentedStock} disewa)',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  );
                }).toList(),
              ),
            ),
          ],

          // Aksi (Edit | Hapus) - Hanya untuk Owner di Menu Stok
          if (isOwner) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: Color(0xFFD97706)),
                  label: Text(
                    item.effectiveRentedStock > 0
                        ? 'Atur Stok (${item.effectiveRentedStock} disewa)'
                        : 'Atur Stok',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706)),
                  ),
                  onPressed: () => _showStockAdjustmentDialog(context, item),
                ),
                const SizedBox(width: 4),
                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => ItemFormDialog.show(context, itemToEdit: item),
                  child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                ),
                const SizedBox(width: 4),
                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _handleDelete(context, item),
                  child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleDelete(BuildContext context, ItemModel item) {
    final notifier = ref.read(appStateProvider.notifier);
    final isRented = notifier.isItemInActiveRental(item.id);

    if (isRented) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Tidak Dapat Menghapus'),
          content: const Text(
            'Produk sedang digunakan dalam transaksi aktif dan tidak dapat dihapus.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Hapus Produk?'),
        content: const Text(
          'Produk ini akan dihapus dari master produk. Pastikan produk tidak sedang digunakan dalam transaksi atau rental aktif.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              try {
                final success = notifier.deleteItem(item.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Produk "${item.name}" berhasil dihapus.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Produk sedang digunakan dalam transaksi aktif dan tidak dapat dihapus.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('StateError: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Hapus Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfoBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showStockAdjustmentDialog(BuildContext context, ItemModel initialItem) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final appState = ref.watch(appStateProvider);
            final currentItem = appState.items.where((it) => it.id == initialItem.id).firstOrNull ?? initialItem;
            final notifier = ref.read(appStateProvider.notifier);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.swap_horiz, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ATUR & KEMBALIKAN STOK',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                currentItem.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ringkasan Status Stok Saat Ini
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStockInfoBadge(
                            label: 'Total Stok',
                            value: '${currentItem.effectiveTotalStock}',
                            color: AppColors.textPrimary,
                          ),
                          Container(width: 1, height: 26, color: Colors.grey.shade300),
                          _buildStockInfoBadge(
                            label: 'Sedang Disewa',
                            value: '${currentItem.effectiveRentedStock}',
                            color: currentItem.effectiveRentedStock > 0 ? const Color(0xFFD97706) : AppColors.textSecondary,
                          ),
                          Container(width: 1, height: 26, color: Colors.grey.shade300),
                          _buildStockInfoBadge(
                            label: 'Tersedia',
                            value: '${currentItem.availableStock}',
                            color: currentItem.availableStock > 0 ? const Color(0xFF16A34A) : AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!currentItem.hasVariants) ...[
                      // PRODUK TANPA VARIAN
                      if (currentItem.rentedStock > 0) ...[
                        Text(
                          'Terdapat ${currentItem.rentedStock} unit barang yang tercatat sedang disewa.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        // Tombol Aksi Cepat: Kembalikan Semua
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.assignment_turned_in, size: 18),
                            label: Text(
                              'Kembalikan Semua (${currentItem.rentedStock} unit) ke Tersedia',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () {
                              notifier.returnRentedStockManually(
                                itemId: currentItem.id,
                                returnQty: currentItem.rentedStock,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Semua ${currentItem.rentedStock} unit "${currentItem.name}" berhasil dikembalikan ke status Tersedia!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Kembalikan 1 unit
                        if (currentItem.rentedStock > 1)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.undo, size: 16),
                              label: const Text('Kembalikan 1 Unit ke Tersedia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              onPressed: () {
                                notifier.returnRentedStockManually(
                                  itemId: currentItem.id,
                                  returnQty: 1,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('1 unit "${currentItem.name}" berhasil dikembalikan ke status Tersedia!'),
                                  ),
                                );
                              },
                            ),
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Semua stok (${currentItem.totalStock} unit) saat ini berstatus Tersedia dan siap disewa.',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // PRODUK DENGAN VARIAN UKURAN
                      if (currentItem.effectiveRentedStock > 0) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.assignment_turned_in, size: 18),
                            label: Text(
                              'Kembalikan Semua Stok Sewa (${currentItem.effectiveRentedStock} unit) ke Tersedia',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () {
                              for (final v in currentItem.variants) {
                                if (v.rentedStock > 0) {
                                  notifier.returnRentedStockManually(
                                    itemId: currentItem.id,
                                    returnQty: v.rentedStock,
                                    variantSize: v.size,
                                  );
                                }
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Semua stok sewa varian "${currentItem.name}" berhasil dikembalikan ke status Tersedia!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Daftar Stok Sewa per Ukuran:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: currentItem.variants.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, vIdx) {
                            final v = currentItem.variants[vIdx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      v.size,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tersedia: ${v.availableStock}/${v.stock} unit (Disewa: ${v.rentedStock})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: v.rentedStock > 0 ? const Color(0xFFD97706) : AppColors.textSecondary,
                                        fontWeight: v.rentedStock > 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (v.rentedStock > 0)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF16A34A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        notifier.returnRentedStockManually(
                                          itemId: currentItem.id,
                                          returnQty: v.rentedStock,
                                          variantSize: v.size,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Ukuran ${v.size} (${v.rentedStock} unit) berhasil dikembalikan ke status Tersedia!'),
                                          ),
                                        );
                                      },
                                      child: const Text('Kembalikan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    const Text('Lengkap', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
