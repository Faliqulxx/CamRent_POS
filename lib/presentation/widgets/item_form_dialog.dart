import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/category_management_dialog.dart';

class _VariantEditItem {
  final String id;
  final TextEditingController sizeCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController priceCtrl;
  final int rentedStock;
  final int damagedStock;

  _VariantEditItem({
    required this.id,
    required String size,
    required int stock,
    int? price,
    this.rentedStock = 0,
    this.damagedStock = 0,
  })  : sizeCtrl = TextEditingController(text: size),
        stockCtrl = TextEditingController(text: stock.toString()),
        priceCtrl = TextEditingController(text: price != null ? price.toString() : '');

  void dispose() {
    sizeCtrl.dispose();
    stockCtrl.dispose();
    priceCtrl.dispose();
  }
}

class ItemFormDialog extends ConsumerStatefulWidget {
  final ItemModel? itemToEdit;

  const ItemFormDialog({super.key, this.itemToEdit});

  static void show(BuildContext context, {ItemModel? itemToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ItemFormDialog(itemToEdit: itemToEdit),
    );
  }

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _dailyPriceCtrl;
  late final TextEditingController _replacementPriceCtrl;
  late final TextEditingController _singleStockCtrl;
  late final TextEditingController _descCtrl;

  late String _selectedCategoryId;
  late bool _isActive;
  final List<_VariantEditItem> _variants = [];

  @override
  void initState() {
    super.initState();
    final it = widget.itemToEdit;

    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _dailyPriceCtrl = TextEditingController(text: it != null ? it.dailyPrice.toString() : '35000');
    _replacementPriceCtrl = TextEditingController(text: it != null ? it.replacementPrice.toString() : '350000');
    _singleStockCtrl = TextEditingController(text: it != null ? it.totalStock.toString() : '5');
    _descCtrl = TextEditingController(text: it?.description ?? '');

    _selectedCategoryId = it?.categoryId ?? 'cat_tenda';
    _isActive = it?.isActive ?? true;

    if (it != null && it.variants.isNotEmpty) {
      for (final v in it.variants) {
        _variants.add(
          _VariantEditItem(
            id: v.id,
            size: v.size,
            stock: v.stock,
            price: v.dailyPrice,
            rentedStock: v.rentedStock,
            damagedStock: v.damagedStock,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dailyPriceCtrl.dispose();
    _replacementPriceCtrl.dispose();
    _singleStockCtrl.dispose();
    _descCtrl.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addNewVariant(int defaultPrice) {
    setState(() {
      _variants.add(
        _VariantEditItem(
          id: 'var_${DateTime.now().microsecondsSinceEpoch}',
          size: '',
          stock: 1,
          price: defaultPrice,
        ),
      );
    });
  }

  void _removeVariant(int index) {
    final v = _variants[index];
    final it = widget.itemToEdit;
    if (it != null) {
      final isRented = ref.read(appStateProvider.notifier).isVariantInActiveRental(it.id, v.sizeCtrl.text.trim());
      if (isRented) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tidak Dapat Dihapus'),
            content: Text('Varian ukuran "${v.sizeCtrl.text}" sedang digunakan dalam rental aktif dan tidak dapat dihapus.'),
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
    }

    setState(() {
      _variants.removeAt(index).dispose();
    });
  }

  int get _computedVariantStock {
    int total = 0;
    for (final v in _variants) {
      final parsed = int.tryParse(v.stockCtrl.text.trim()) ?? 0;
      total += parsed;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itemToEdit != null;
    final appState = ref.watch(appStateProvider);

    // Filter categories (exclude 'cat_all')
    final categories = appState.categories.where((c) => c.id != 'cat_all').toList();

    // Ensure _selectedCategoryId exists
    if (!categories.any((c) => c.id == _selectedCategoryId) && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    final selectedCategory = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => categories.first,
    );
    final requiresSize = selectedCategory.requiresSize;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header (Clean, professional, without emojis/product icons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'EDIT PRODUK' : 'TAMBAH PRODUK BARU',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Nama Produk
                      const Text(
                        'Nama Produk',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Sepatu Hiking Eiger / Tenda Camping 4P',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama produk wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Field 2: Kategori & Kelola Kategori
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kategori',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          InkWell(
                            onTap: () => CategoryManagementDialog.show(context),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune, size: 14, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Kelola Kategori',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                        decoration: const InputDecoration(isDense: true),
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.requiresSize ? '${c.name} (Memerlukan Ukuran)' : c.name,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategoryId = val;
                              final newCat = categories.firstWhere((c) => c.id == val, orElse: () => categories.first);
                              // If newly selected category requires size and list is empty, prepopulate 1 row
                              if (newCat.requiresSize && _variants.isEmpty) {
                                final basePrice = int.tryParse(_dailyPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 35000;
                                _addNewVariant(basePrice);
                              }
                            });
                          }
                        },
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Pilih kategori produk';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Field 3: Harga Sewa / Hari & Harga Ganti
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Harga Sewa / Hari',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _dailyPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixText: 'Rp ',
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    setState(() {});
                                  },
                                  validator: (val) {
                                    if (val == null || int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                      return 'Harga sewa tidak valid';
                                    }
                                    final parsed = int.parse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                    if (parsed < 0) return 'Harga tidak boleh negatif';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Harga Ganti Hilang',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _replacementPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixText: 'Rp ',
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (val == null || int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                      return 'Harga ganti tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section 4: STOK & VARIAN UKURAN
                      if (requiresSize) ...[
                        // PRODUK DENGAN UKURAN (Tabel Varian)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'VARIAN UKURAN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Total Stok: $_computedVariantStock unit',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text('Ukuran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: Text('Harga/Hari (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 48,
                                      child: Center(
                                        child: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Variant Rows
                              if (_variants.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Belum ada varian ukuran. Tekan "+ Tambah Ukuran" di bawah.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                )
                              else
                                ..._variants.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final v = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        // Ukuran
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: v.sizeCtrl,
                                            decoration: const InputDecoration(
                                              hintText: 'Misal: 39 / L',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Stok
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: v.stockCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              hintText: '0',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Harga/Hari
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: v.priceCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: _dailyPriceCtrl.text.trim().isEmpty ? '35000' : _dailyPriceCtrl.text.trim(),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Aksi Hapus
                                        SizedBox(
                                          width: 48,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                            onPressed: () => _removeVariant(idx),
                                            tooltip: 'Hapus Ukuran',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final basePrice = int.tryParse(_dailyPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 35000;
                                  _addNewVariant(basePrice);
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Ukuran'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // PRODUK TANPA UKURAN (Field Stok Tunggal)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stok (Unit)',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _singleStockCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: 'Contoh: 5',
                                      isDense: true,
                                    ),
                                    validator: (val) {
                                      if (val == null || int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                        return 'Stok wajib diisi dengan angka valid';
                                      }
                                      final parsed = int.parse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                      if (parsed < 0) return 'Stok tidak boleh negatif';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Deskripsi Opsional
                      const Text(
                        'Deskripsi Produk (Opsional)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Catatan spesifikasi atau kondisi produk...',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Aktif
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Status Aktif (Tersedia untuk disewa)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Nonaktifkan jika produk sedang ditarik dari katalog rental', style: TextStyle(fontSize: 12)),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    onPressed: () => _handleSave(requiresSize),
                    child: Text(
                      isEdit ? 'Simpan Perubahan' : 'Tambah Produk',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave(bool requiresSize) {
    if (!_formKey.currentState!.validate()) return;

    final dailyPrice = int.parse(_dailyPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final replacementPrice = int.parse(_replacementPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

    List<ProductVariantModel> finalVariants = [];
    int totalStock = 0;

    if (requiresSize) {
      if (_variants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori ini memerlukan varian ukuran. Tambahkan minimal 1 ukuran.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final Set<String> seenSizes = {};
      for (final v in _variants) {
        final size = v.sizeCtrl.text.trim();
        if (size.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua varian ukuran wajib diisi namanya.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final lowerSize = size.toLowerCase();
        if (seenSizes.contains(lowerSize)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ukuran "$size" duplikat. Setiap ukuran harus unik.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        seenSizes.add(lowerSize);

        final stock = int.tryParse(v.stockCtrl.text.trim()) ?? 0;
        if (stock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok ukuran tidak boleh negatif.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        int? customPrice;
        if (v.priceCtrl.text.trim().isNotEmpty) {
          customPrice = int.tryParse(v.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
          if (customPrice != null && customPrice < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Harga varian tidak boleh negatif.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        finalVariants.add(
          ProductVariantModel(
            id: v.id,
            size: size,
            stock: stock,
            rentedStock: v.rentedStock,
            damagedStock: v.damagedStock,
            dailyPrice: customPrice ?? dailyPrice,
          ),
        );
        totalStock += stock;
      }
    } else {
      totalStock = int.parse(_singleStockCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    try {
      if (widget.itemToEdit != null) {
        final updated = widget.itemToEdit!.copyWith(
          name: _nameCtrl.text.trim(),
          categoryId: _selectedCategoryId,
          dailyPrice: dailyPrice,
          replacementPrice: replacementPrice,
          totalStock: totalStock,
          variants: finalVariants,
          description: _descCtrl.text.trim(),
          isActive: _isActive,
        );
        ref.read(appStateProvider.notifier).updateItem(updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk "${updated.name}" berhasil diperbarui.')),
        );
      } else {
        final newItem = ItemModel(
          id: 'itm_${DateTime.now().millisecondsSinceEpoch}',
          categoryId: _selectedCategoryId,
          name: _nameCtrl.text.trim(),
          dailyPrice: dailyPrice,
          replacementPrice: replacementPrice,
          totalStock: totalStock,
          rentedStock: 0,
          damagedStock: 0,
          variants: finalVariants,
          description: _descCtrl.text.trim(),
          isActive: _isActive,
        );
        ref.read(appStateProvider.notifier).addItem(newItem);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk "${newItem.name}" berhasil ditambahkan.')),
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
  }
}
