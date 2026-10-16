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

          // Harga Sewa / Hari
          Text(
            '${CurrencyFormatter.format(item.dailyPrice)} / hari',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 10),

          // Varian Ukuran & Stok
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Varian Ukuran:',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      variantText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Stok:',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.effectiveTotalStock} unit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
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
                    '${v.size}: ${v.availableStock}/${v.stock} unit',
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
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => ItemFormDialog.show(context, itemToEdit: item),
                  child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                ),
                const SizedBox(width: 6),
                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
}
