import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

enum ReportPeriodFilter {
  all,
  today,
  last7Days,
  thisMonth,
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriodFilter _periodFilter = ReportPeriodFilter.all;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final allRentals = appState.rentals;
    final isAdmin = appState.currentRole == AppRole.admin;

    // Filter rentals berdasarkan periode waktu
    final rentals = _filterRentalsByPeriod(allRentals, _periodFilter);

    // Hitung pemasukan per metode dan tipe pembayaran (kecuali yang dibatalkan)
    int cashTotal = 0;
    int transferTotal = 0;
    int qrisTotal = 0;

    int dpTotal = 0;
    int settlementTotal = 0;
    int fineTotal = 0;

    for (final r in rentals) {
      if (r.status == RentalStatus.dibatalkan) continue;
      for (final p in r.payments) {
        if (p.method == PaymentMethod.tunai) cashTotal += p.amount;
        if (p.method == PaymentMethod.transfer) transferTotal += p.amount;
        if (p.method == PaymentMethod.qris) qrisTotal += p.amount;

        if (p.type == PaymentType.dp) dpTotal += p.amount;
        if (p.type == PaymentType.pelunasan) settlementTotal += p.amount;
        if (p.type == PaymentType.denda) fineTotal += p.amount;
      }
    }

    final grandTotalPemasukan = cashTotal + transferTotal + qrisTotal;

    // Hitung jaminan fisik & deposit uang aktif
    final activeCollateralsCount = rentals
        .where((r) => r.status == RentalStatus.aktif && r.collateral != null && !r.collateral!.isReturned)
        .length;

    final activeDepositsAmount = rentals
        .where((r) => r.status == RentalStatus.aktif && r.deposit != null && !r.deposit!.isSettled)
        .fold(0, (sum, r) => sum + (r.deposit?.amount ?? 0));

    // Analisis keterlambatan dan piutang (GRATIS untuk semua user)
    final overdueRentals = rentals.where((r) => r.isOverdue).toList();
    final overdueCount = overdueRentals.length;

    // Total piutang (sisa tagihan yang belum dilunasi pada rental aktif/terlambat)
    final totalPiutang = rentals
        .where((r) => r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian)
        .fold(0, (sum, r) => sum + r.remainingRentalFee);

    // Daftar transaksi bermasalah / belum lunas
    final problematicRentals = rentals.where((r) {
      final isNotSettled = r.status == RentalStatus.aktif || r.status == RentalStatus.dikembalikanSebagian;
      return isNotSettled && (r.isOverdue || r.remainingRentalFee > 0);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewTab(
              context,
              isAdmin: isAdmin,
              activeCashierName: appState.activeCashierName,
              grandTotalPemasukan: grandTotalPemasukan,
              cashTotal: cashTotal,
              transferTotal: transferTotal,
              qrisTotal: qrisTotal,
              dpTotal: dpTotal,
              settlementTotal: settlementTotal,
              fineTotal: fineTotal,
              activeCollateralsCount: activeCollateralsCount,
              activeDepositsAmount: activeDepositsAmount,
              overdueCount: overdueCount,
              totalPiutang: totalPiutang,
              problematicRentals: problematicRentals,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RINGKASAN KEUANGAN & PIUTANG TOKO
  // ==========================================
  Widget _buildOverviewTab(
    BuildContext context, {
    required bool isAdmin,
    required String activeCashierName,
    required int grandTotalPemasukan,
    required int cashTotal,
    required int transferTotal,
    required int qrisTotal,
    required int dpTotal,
    required int settlementTotal,
    required int fineTotal,
    required int activeCollateralsCount,
    required int activeDepositsAmount,
    required int overdueCount,
    required int totalPiutang,
    required List<RentalModel> problematicRentals,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Rentang Periode Laporan & Tombol Export CSV
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    const Text('Periode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    _periodFilterChip('Semua Periode', ReportPeriodFilter.all),
                    _periodFilterChip('Hari Ini', ReportPeriodFilter.today),
                    _periodFilterChip('7 Hari Terakhir', ReportPeriodFilter.last7Days),
                    _periodFilterChip('Bulan Ini', ReportPeriodFilter.thisMonth),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showExportCsvDialog(context, ref.read(appStateProvider).rentals),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 1. Header Banner & Total Pemasukan
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isAdmin ? 'Laporan Keuangan & Omzet (Owner)' : 'Ringkasan Kasir',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAdmin ? 'Hak Akses Owner' : 'Kasir: $activeCashierName',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Total Uang Masuk:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.format(grandTotalPemasukan),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Pemasukan per Metode Pembayaran
        const Text(
          'Pemasukan Berdasarkan Metode Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _paymentMethodCard('Tunai', CurrencyFormatter.format(cashTotal), Icons.money, AppColors.success),
            const SizedBox(width: 10),
            _paymentMethodCard('Transfer', CurrencyFormatter.format(transferTotal), Icons.account_balance, AppColors.info),
            const SizedBox(width: 10),
            _paymentMethodCard('QRIS', CurrencyFormatter.format(qrisTotal), Icons.qr_code_2, AppColors.purple),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Rincian Komponen Pemasukan
        const Text(
          'Rincian Komponen Pemasukan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _flowRow('Penerimaan Uang Muka (DP)', CurrencyFormatter.format(dpTotal)),
                const Divider(height: 14, color: AppColors.border),
                _flowRow('Penerimaan Pelunasan Sewa', CurrencyFormatter.format(settlementTotal)),
                const Divider(height: 14, color: AppColors.border),
                _flowRow('Penerimaan Denda (Telat / Kerusakan)', CurrencyFormatter.format(fineTotal)),
                const Divider(height: 14, color: AppColors.border),
                _flowRow('Total Pemasukan Bersih', CurrencyFormatter.format(grandTotalPemasukan), isBold: true),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 4. Titipan & Pengawasan Toko (Jaminan & Deposit)
        const Text(
          'Titipan & Pengawasan Toko',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                        SizedBox(width: 6),
                        Text('Jaminan Fisik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$activeCollateralsCount Dokumen',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                    const Text('KTP/SIM/KTM dipegang toko', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, color: AppColors.accent, size: 20),
                        SizedBox(width: 6),
                        Text('Deposit Uang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(activeDepositsAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.accent),
                    ),
                    const Text('Dana jaminan tunai aktif', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 5. ANALISIS KETERLAMBATAN & PIUTANG (100% GRATIS)
        _buildOverdueAndReceivablesSection(
          context,
          overdueCount: overdueCount,
          totalPiutang: totalPiutang,
          activeDepositsAmount: activeDepositsAmount,
          problematicRentals: problematicRentals,
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 2: ANALISIS KETERLAMBATAN & PIUTANG (GRATIS)
  // ==========================================
  Widget _buildOverdueAndReceivablesSection(
    BuildContext context, {
    required int overdueCount,
    required int totalPiutang,
    required int activeDepositsAmount,
    required List<RentalModel> problematicRentals,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Analisis Keterlambatan & Piutang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pantau transaksi terlambat, piutang sisa pembayaran sewa, dan pengembalian jaminan.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // 3 Cards: Transaksi Terlambat, Total Piutang, Deposit Ditahan
        Row(
          children: [
            _metricStatCard(
              title: 'Transaksi Terlambat',
              value: '$overdueCount Unit',
              subtitle: overdueCount > 0 ? 'Perlu tindakan segera' : 'Semua tepat waktu',
              color: overdueCount > 0 ? AppColors.danger : AppColors.success,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 8),
            _metricStatCard(
              title: 'Total Piutang Sewa',
              value: CurrencyFormatter.format(totalPiutang),
              subtitle: 'Sisa belum dilunasi',
              color: totalPiutang > 0 ? Colors.orange.shade800 : AppColors.success,
              icon: Icons.pending_actions_outlined,
            ),
            const SizedBox(width: 8),
            _metricStatCard(
              title: 'Deposit Ditahan',
              value: CurrencyFormatter.format(activeDepositsAmount),
              subtitle: 'Titipan jaminan aktif',
              color: AppColors.info,
              icon: Icons.security_outlined,
            ),
          ],
        ),



        const SizedBox(height: 12),

        // Daftar Transaksi Bermasalah & Belum Lunas
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_late_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daftar Transaksi Bermasalah & Belum Lunas (${problematicRentals.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (problematicRentals.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                        SizedBox(height: 6),
                        Text(
                          'Bagus! Tidak ada transaksi terlambat atau piutang tertunggak.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Seluruh pengembalian dan pelunasan rental berjalan lancar.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: problematicRentals.length,
                  separatorBuilder: (_, __) => const Divider(height: 14, color: AppColors.border),
                  itemBuilder: (ctx, idx) {
                    final r = problematicRentals[idx];
                    return _buildProblematicRentalItem(r);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProblematicRentalItem(RentalModel r) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (r.isOverdue) {
      statusColor = AppColors.danger;
      statusLabel = 'Terlambat (${r.overdueDays} Hari)';
      statusIcon = Icons.error_outline;
    } else if (r.remainingRentalFee > 0) {
      statusColor = Colors.orange.shade800;
      statusLabel = 'Belum Lunas';
      statusIcon = Icons.timelapse;
    } else {
      statusColor = AppColors.info;
      statusLabel = 'Menunggu Pengembalian';
      statusIcon = Icons.hourglass_top_outlined;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator bar
        Container(
          width: 4,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),

        // Transaksi info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${r.rentalNumber} • Jatuh Tempo: ${DateFormatter.format(r.scheduledReturnDate)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sisa Piutang: ${CurrencyFormatter.format(r.remainingRentalFee)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: r.remainingRentalFee > 0 ? Colors.orange.shade900 : AppColors.textPrimary,
                    ),
                  ),
                  if (r.deposit != null && !r.deposit!.isSettled)
                    Text(
                      '• Deposit Ditahan: ${CurrencyFormatter.format(r.deposit!.amount)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }



  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _metricStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.85), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodFilterChip(String label, ReportPeriodFilter filter) {
    final isSelected = _periodFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSelected: (_) {
          setState(() => _periodFilter = filter);
        },
      ),
        );
  }

  List<RentalModel> _filterRentalsByPeriod(List<RentalModel> rentals, ReportPeriodFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case ReportPeriodFilter.all:
        return rentals;
      case ReportPeriodFilter.today:
        return rentals.where((r) {
          final p = r.pickupDate;
          return p.year == today.year && p.month == today.month && p.day == today.day;
        }).toList();
      case ReportPeriodFilter.last7Days:
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        return rentals.where((r) => r.pickupDate.isAfter(sevenDaysAgo)).toList();
      case ReportPeriodFilter.thisMonth:
        return rentals.where((r) => r.pickupDate.year == today.year && r.pickupDate.month == today.month).toList();
    }
  }

  Widget _paymentMethodCard(String title, String amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _flowRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showExportCsvDialog(BuildContext context, List<RentalModel> rentals) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('No Transaksi,Nama Pelanggan,No WhatsApp,Tgl Ambil,Jatuh Tempo,Durasi (Hari),Total Sewa,DP Dibayar,Sisa Tagihan,Status,Metode Bayar,Daftar Barang');

    for (final r in rentals) {
      final itemsSummary = r.items.map((i) => '${i.nameSnapshot} (${i.qty} unit)').join('; ');
      final payMethodStr = r.payments.isNotEmpty ? r.payments.first.method.name.toUpperCase() : 'TUNAI';
      final statusStr = r.status.name.toUpperCase();
      buffer.writeln(
        '"${r.rentalNumber}","${r.customer.name}","${r.customer.phone}","${DateFormatter.format(r.pickupDate)}","${DateFormatter.format(r.scheduledReturnDate)}",${r.durationDays},${r.totalSewa},${r.dpPaid},${r.remainingRentalFee},"$statusStr","$payMethodStr","${itemsSummary.replaceAll('"', '""')}"',
      );
    }

    final csvText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_chart_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Laporan CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Data transaksi sesuai database riil', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${rentals.length} transaksi siap diekspor.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvText,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin CSV ke Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text('Data CSV laporan berhasil disalin ke clipboard!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
