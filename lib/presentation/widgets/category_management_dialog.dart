import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CategoryManagementDialog(),
    );
  }

  @override
  ConsumerState<CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends ConsumerState<CategoryManagementDialog> {
  final _nameController = TextEditingController();
  bool _requiresSize = false;
  bool _isAdding = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleAddCategory() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Nama kategori wajib diisi.');
      return;
    }

    try {
      ref.read(appStateProvider.notifier).addCategory(
            name: name,
            requiresSize: _requiresSize,
          );

      _nameController.clear();
      setState(() {
        _isAdding = false;
        _requiresSize = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('Kategori "$name" berhasil ditambahkan!'),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('StateError: ', ''));
    }
  }

  void _confirmDelete(BuildContext context, String catId, String catName, int itemCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Hapus Kategori?'),
        content: Text(
          itemCount > 0
              ? 'Kategori "$catName" saat ini memiliki $itemCount produk. Jika dihapus, produk tersebut akan dialihkan ke kategori "Semua".\n\nYakin ingin menghapus?'
              : 'Yakin ingin menghapus kategori "$catName"?',
          style: const TextStyle(fontSize: 13),
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
                final success = ref.read(appStateProvider.notifier).deleteCategory(catId);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text('Kategori "$catName" berhasil dihapus.'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(e.toString().replaceAll('StateError: ', '')),
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isOwner = appState.currentRole == AppRole.admin;
    final categories = appState.categories;
    final items = appState.items;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 620),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'KELOLA KATEGORI PRODUK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Tambah Kategori (Only for Owner)
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Tambah Kategori Baru',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                const Spacer(),
                                if (!_isAdding)
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() => _isAdding = true),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _isAdding = false;
                                      _errorMessage = null;
                                    }),
                                    child: const Text('Batal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ),
                              ],
                            ),
                            if (_isAdding) ...[
                              const SizedBox(height: 12),
                              if (_errorMessage != null) ...[
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                              ],
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: Sepatu Outdoor, Sandal, Tenda...',
                                  labelText: 'Nama Kategori *',
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _handleAddCategory(),
                              ),
                              const SizedBox(height: 12),
                              // Opsi Memerlukan Varian Ukuran
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Memerlukan Varian Ukuran',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: const Text(
                                    'Aktifkan jika produk dalam kategori ini wajib memiliki ukuran (sepatu, pakaian, jaket)',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  value: _requiresSize,
                                  onChanged: (val) => setState(() => _requiresSize = val),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleAddCategory,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Simpan Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Daftar Kategori
                    Row(
                      children: [
                        Text(
                          'Daftar Kategori (${categories.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (ctx, idx) {
                        final cat = categories[idx];
                        final isAll = cat.id == 'cat_all';
                        final count = isAll
                            ? items.length
                            : items.where((it) => it.categoryId == cat.id).length;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontWeight: isAll ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isAll)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Default', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cat.requiresSize ? Colors.blue.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: cat.requiresSize ? Colors.blue.shade200 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    cat.requiresSize ? 'Varian Ukuran' : 'Tanpa Ukuran',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: cat.requiresSize ? Colors.blue.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '$count produk terdaftar',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: isAll || !isOwner
                              ? null
                              : Tooltip(
                                  message: 'Hapus kategori',
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                    onPressed: () => _confirmDelete(context, cat.id, cat.name, count),
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
