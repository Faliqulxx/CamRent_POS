import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/data/models/item_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/category_management_dialog.dart';

class _VariantEditItem {
  final String id;
  final TextEditingController sizeCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController priceCtrl;
  int rentedStock;
  final int damagedStock;

  _VariantEditItem({
    required this.id,
    required String size,
    int? stock,
    int? price,
    this.rentedStock = 0,
    this.damagedStock = 0,
  })  : sizeCtrl = TextEditingController(text: size),
        stockCtrl = TextEditingController(text: stock != null && stock > 0 ? stock.toString() : ''),
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
  late final TextEditingController _priceTwoDaysCtrl;
  late final TextEditingController _replacementPriceCtrl;
  late final TextEditingController _singleStockCtrl;
  late final TextEditingController _singleRentedStockCtrl;
  late final TextEditingController _descCtrl;

  late String _selectedCategoryId;
  late bool _isActive;
  final List<_VariantEditItem> _variants = [];

  @override
  void initState() {
    super.initState();
    final it = widget.itemToEdit;

    final initialPrice1 = it != null ? it.dailyPrice : 35000;
    final initialPrice2 = it != null
        ? (it.effectivePriceTwoOrMoreDays > 0 ? it.effectivePriceTwoOrMoreDays : it.dailyPrice)
        : 20000;

    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _dailyPriceCtrl = TextEditingController(text: initialPrice1.toString());
    _priceTwoDaysCtrl = TextEditingController(text: initialPrice2.toString());
    _replacementPriceCtrl = TextEditingController(text: it != null ? it.replacementPrice.toString() : '350000');
    // Stok total kosong saat tambah baru agar Owner mengisi sendiri (tidak ada default 5)
    _singleStockCtrl = TextEditingController(text: it != null ? it.totalStock.toString() : '');
    _singleRentedStockCtrl = TextEditingController(text: it != null ? it.rentedStock.toString() : '0');
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
    _priceTwoDaysCtrl.dispose();
    _replacementPriceCtrl.dispose();
    _singleStockCtrl.dispose();
    _singleRentedStockCtrl.dispose();
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
          stock: null, // Kosong agar Owner menentukan sendiri jumlah stok
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
                      const SizedBox(height: 16),

                      // Section: HARGA BERDASARKAN DURASI SEWA
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Harga Berdasarkan Durasi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Atur harga sewa berdasarkan lama penyewaan.',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 1. SEWA 1 HARI
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                    ),
                                    child: const Text(
                                      '1 Hari',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Harga: ',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _dailyPriceCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            prefixText: 'Rp ',
                                            suffixText: '/ hari',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                          onChanged: (val) => setState(() {}),
                                          validator: (val) {
                                            if (val == null || int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                              return 'Harga sewa 1 hari tidak valid';
                                            }
                                            final parsed = int.parse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                            if (parsed <= 0) return 'Harga harus lebih dari 0';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Berlaku untuk sewa tepat 1 hari.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 2. SEWA 2 HARI ATAU LEBIH
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                    ),
                                    child: const Text(
                                      '2 Hari atau Lebih',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Harga: ',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _priceTwoDaysCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            prefixText: 'Rp ',
                                            suffixText: '/ hari',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                          onChanged: (val) => setState(() {}),
                                          validator: (val) {
                                            if (val == null || int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                                              return 'Harga sewa 2+ hari tidak valid';
                                            }
                                            final parsed = int.parse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                            if (parsed <= 0) return 'Harga harus lebih dari 0';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Berlaku otomatis untuk semua sewa dengan durasi 2 hari atau lebih.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // PREVIEW PERHITUNGAN
                            _buildPreviewCard(
                              int.tryParse(_dailyPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                              int.tryParse(_priceTwoDaysCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                            ),
                          ],
                        ),
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
                        // PRODUK TANPA UKURAN (Field Stok Total & Sedang Disewa)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Stok (Unit)',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _singleStockCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: 'Contoh: 12',
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Total stok wajib diisi';
                                          }
                                          final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                          if (parsed == null || parsed < 0) return 'Stok tidak boleh negatif';
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
                                      Row(
                                        children: [
                                          const Text(
                                            'Sedang Disewa',
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                          const Spacer(),
                                          if ((int.tryParse(_singleRentedStockCtrl.text) ?? 0) > 0)
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _singleRentedStockCtrl.text = '0';
                                                });
                                              },
                                              child: const Text(
                                                'Kembalikan ke 0',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _singleRentedStockCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: '0',
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                        validator: (val) {
                                          final parsed = int.tryParse(val?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                                          if (parsed == null || parsed < 0) return 'Stok sewa wajib valid';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final tot = int.tryParse(_singleStockCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                final rnt = int.tryParse(_singleRentedStockCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                final avail = (tot - rnt) > 0 ? (tot - rnt) : 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Stok Tersedia = $tot (Total) − $rnt (Disewa) = $avail unit siap disewa',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
    int singleRented = 0;

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

        final stockText = v.stockCtrl.text.trim();
        if (stockText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stok untuk ukuran "$size" wajib diisi.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final stock = int.tryParse(stockText) ?? 0;
        if (stock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stok ukuran "$size" tidak boleh negatif.'),
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
      final stockInput = _singleStockCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (stockInput.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total stok wajib diisi.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      totalStock = int.parse(stockInput);
      singleRented = int.tryParse(_singleRentedStockCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    // Bangun aturan durasi: 2 harga (1 hari dan 2+ hari)
    final priceTwoOrMoreRaw = int.tryParse(_priceTwoDaysCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final priceTwoOrMore = (priceTwoOrMoreRaw != null && priceTwoOrMoreRaw > 0)
        ? priceTwoOrMoreRaw
        : dailyPrice;

    final List<DurationPriceRule> finalDurationRules = [
      DurationPriceRule(
        days: 1,
        pricePerDay: dailyPrice,
        isActive: true,
        isPremium: false,
      ),
      DurationPriceRule(
        days: 2,
        pricePerDay: priceTwoOrMore,
        isActive: true,
        isPremium: false,
      ),
    ];

    try {
      if (widget.itemToEdit != null) {
        final updated = widget.itemToEdit!.copyWith(
          name: _nameCtrl.text.trim(),
          categoryId: _selectedCategoryId,
          dailyPrice: dailyPrice,
          priceTwoOrMoreDays: priceTwoOrMore,
          replacementPrice: replacementPrice,
          totalStock: totalStock,
          rentedStock: requiresSize ? widget.itemToEdit!.effectiveRentedStock : singleRented,
          variants: finalVariants,
          durationPricing: finalDurationRules,
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
          priceTwoOrMoreDays: priceTwoOrMore,
          replacementPrice: replacementPrice,
          totalStock: totalStock,
          rentedStock: requiresSize ? 0 : singleRented,
          damagedStock: 0,
          variants: finalVariants,
          durationPricing: finalDurationRules,
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

  Widget _buildPreviewCard(int priceOneDay, int priceTwoOrMoreDays) {
    final previewDurations = [1, 2, 3, 7];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'PREVIEW PERHITUNGAN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tabel Simulasi
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: previewDurations.map((d) {
                final rate = (d == 1) ? priceOneDay : priceTwoOrMoreDays;
                final total = d * rate;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          '$d hari',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      const Text('→', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                      Text(
                        '($d × ${CurrencyFormatter.format(rate)}/hr)',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
