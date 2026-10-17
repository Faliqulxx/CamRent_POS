import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/status_pill.dart';
import 'package:camprent_pos/presentation/widgets/return_inspection_dialog.dart';
import 'package:camprent_pos/presentation/widgets/receipt_preview_dialog.dart';

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  int _selectedFilterIndex = 0;
  String _searchQuery = '';

  final List<String> _filterTabs = [
    'Semua',
    'Aktif',
    'Jatuh Tempo Hari Ini',
    'Terlambat',
    'Selesai',
    'Dibatalkan',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final rentals = appState.rentals;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Apply filter
    final filteredRentals = rentals.where((r) {
      // Search
      final q = _searchQuery.toLowerCase();
      final matchSearch = r.rentalNumber.toLowerCase().contains(q) ||
          r.customer.name.toLowerCase().contains(q) ||
          r.customer.phone.contains(q);
      if (!matchSearch) return false;

      // Filter tabs
      switch (_selectedFilterIndex) {
        case 1: // Aktif
          return r.status == RentalStatus.aktif;
        case 2: // Jatuh tempo hari ini
          final returnDue = DateTime(r.scheduledReturnDate.year, r.scheduledReturnDate.month, r.scheduledReturnDate.day);
          return r.status == RentalStatus.aktif && today.isAtSameMomentAs(returnDue);
        case 3: // Terlambat
          return r.isOverdue;
        case 4: // Selesai
          return r.status == RentalStatus.selesai;
        case 5: // Dibatalkan
          return r.status == RentalStatus.dibatalkan;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Filter bar & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari no. transaksi (RNT-...), nama, atau no. WA...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_filterTabs.length, (idx) {
                      final isSel = _selectedFilterIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_filterTabs[idx]),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => _selectedFilterIndex = idx),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Rentals List
          Expanded(
            child: filteredRentals.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'Tidak ada transaksi pada filter ini',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filteredRentals.length,
                    itemBuilder: (ctx, idx) {
                      final rental = filteredRentals[idx];
                      return _RentalCard(rental: rental);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RentalCard extends ConsumerWidget {
  final RentalModel rental;

  const _RentalCard({required this.rental});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    final isReturnable = rental.status == RentalStatus.aktif || rental.status == RentalStatus.dikembalikanSebagian;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: No Transaksi & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          rental.rentalNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill.fromRental(rental),
              ],
            ),
            const Divider(height: 16),

            // Customer & Dates
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: rental.customer.isBlacklisted ? AppColors.danger : AppColors.primary,
                  child: Text(
                    rental.customer.name[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rental.customer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rental.customer.isBlacklisted) ...[
                            const SizedBox(width: 6),
                            StatusPill.blacklist(),
                          ],
                        ],
                      ),
                      Text(
                        'WA: ${rental.customer.phone}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Collateral pill
                StatusPill.collateral(rental.collateral, rental.deposit),
              ],
            ),

            const SizedBox(height: 10),

            // Rental Schedule & Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tgl Ambil', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      Text(DateFormatter.format(rental.pickupDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${rental.durationDays} Hari',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Jatuh Tempo', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      Text(
                        DateFormatter.format(rental.scheduledReturnDate),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: rental.isOverdue ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Items List Summary
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rental.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${it.nameSnapshot} (${it.qty} unit)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(it.priceSnapshot * it.qty * rental.durationDays),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const Divider(height: 16),

            // Financials Summary - Responsive Wrap (Eliminates yellow-black hazard overflow on mobile)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${CurrencyFormatter.format(rental.totalSewa)} (DP: ${CurrencyFormatter.format(rental.dpPaid)})', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      rental.status == RentalStatus.selesai
                          ? 'Status: LUNAS'
                          : 'Sisa Pelunasan: ${CurrencyFormatter.format(rental.remainingRentalFee)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: rental.status == RentalStatus.selesai ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cetak Ulang Button
                    IconButton(
                      tooltip: 'Lihat / Cetak Ulang Struk',
                      icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.textSecondary),
                      onPressed: () {
                        ReceiptPreviewDialog.show(
                          context,
                          rental: rental,
                          settings: appState.settings,
                          printerConfig: appState.printerConfig,
                          isReturnReceipt: rental.status == RentalStatus.selesai,
                          isCopy: true,
                        );
                      },
                    ),

                    if (isReturnable) ...[
                      const SizedBox(width: 4),
                      if (appState.currentRole == AppRole.admin) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, color: AppColors.danger),
                                    SizedBox(width: 8),
                                    Text('Batalkan Transaksi?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                content: Text(
                                  'Apakah Anda yakin ingin membatalkan transaksi #${rental.rentalNumber}?\n\nSemua stok barang yang disewa (${rental.items.map((i) => '${i.nameSnapshot} x${i.qty}').join(', ')}) akan dikembalikan otomatis ke stok tersedia di Supabase.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                actions: [
                                  OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Tutup'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      final success = ref.read(appStateProvider.notifier).cancelRental(rental.id);
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppColors.danger,
                                            content: Text('Transaksi #${rental.rentalNumber} berhasil dibatalkan dan stok telah dipulihkan.'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Batalkan Transaksi'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Batalkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rental.isOverdue ? AppColors.danger : AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.assignment_return_outlined, size: 16),
                        label: const Text('Cek & Kembali', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ReturnInspectionDialog.show(context, rental);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
