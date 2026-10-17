import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/status_pill.dart';
import 'package:camprent_pos/presentation/widgets/customer_selector_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final customers = appState.customers;
    final isAdmin = appState.currentRole == AppRole.admin;

    final filtered = customers.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau WhatsApp pelanggan...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
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
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                  onPressed: () => CustomerSelectorDialog.show(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = filtered[idx];
                final customerRentals = appState.rentals.where((r) => r.customer.id == c.id).toList();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: c.isBlacklisted ? AppColors.danger : AppColors.primary,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0] : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (c.isBlacklisted)
                                        StatusPill.blacklist(),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'No. WhatsApp: ${c.phone}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${customerRentals.length}x Sewa',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        if (c.address.isNotEmpty || c.note.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (c.address.isNotEmpty)
                            Text('Alamat: ${c.address}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (c.note.isNotEmpty)
                            Text('Catatan / NIK: ${c.note}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        if (c.isBlacklisted && c.blacklistReason != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.block, color: AppColors.danger, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Alasan Blacklist: ${c.blacklistReason}',
                                    style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isAdmin) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  c.isBlacklisted ? Icons.check_circle_outline : Icons.block,
                                  size: 16,
                                  color: c.isBlacklisted ? AppColors.success : AppColors.danger,
                                ),
                                label: Text(
                                  c.isBlacklisted ? 'Cabut Blacklist' : 'Tandai Blacklist',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.isBlacklisted ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                                onPressed: () {
                                  ref.read(appStateProvider.notifier).toggleCustomerBlacklist(
                                        c.id,
                                        reason: 'Diblacklist oleh owner via panel admin',
                                      );
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.history_outlined, size: 16, color: AppColors.primary),
                                label: const Text('Riwayat', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _showCustomerHistoryDialog(context, c, customerRentals);
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                tooltip: 'Hapus Pelanggan',
                                onPressed: () {
                                  final hasActive = customerRentals.any((r) => r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian);
                                  if (hasActive) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text('Pelanggan ini sedang memiliki transaksi rental aktif dan tidak dapat dihapus.'),
                                      ),
                                    );
                                    return;
                                  }

                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      title: const Text('Hapus Pelanggan?'),
                                      content: Text(
                                        'Yakin ingin menghapus data pelanggan "${c.name}"?\nData pelanggan akan dihapus secara permanen dari Supabase.',
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
                                            final ok = ref.read(appStateProvider.notifier).deleteCustomer(c.id);
                                            if (ok) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: AppColors.danger,
                                                  content: Text('Pelanggan "${c.name}" berhasil dihapus.'),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerHistoryDialog(BuildContext context, CustomerModel customer, List<RentalModel> rentals) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Riwayat Transaksi: ${customer.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: rentals.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Belum ada riwayat transaksi sewa.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rentals.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final r = rentals[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Text(r.rentalNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          StatusPill.fromRental(r),
                        ],
                      ),
                      subtitle: Text(
                        '${r.durationDays} hari • ${r.items.map((it) => "${it.nameSnapshot} x${it.qty}").join(", ")}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        'Rp ${r.totalSewa}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
