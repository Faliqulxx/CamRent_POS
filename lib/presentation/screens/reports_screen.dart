import 'package:flutter/material.dart';
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

enum AnalyticsPeriodTab {
  daily,
  weekly,
  monthly,
  yearly,
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedMainTab = 0; // 0: Ringkasan & Piutang (Gratis), 1: Analitik Lanjutan (Premium)
  ReportPeriodFilter _periodFilter = ReportPeriodFilter.all;
  AnalyticsPeriodTab _analyticsTab = AnalyticsPeriodTab.weekly;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final allRentals = appState.rentals;
    final isAdmin = appState.currentRole == AppRole.admin;

    // Filter rentals berdasarkan periode waktu
    final rentals = _filterRentalsByPeriod(allRentals, _periodFilter);

    // Hitung pemasukan per metode dan tipe pembayaran
    int cashTotal = 0;
    int transferTotal = 0;
    int qrisTotal = 0;

    int dpTotal = 0;
    int settlementTotal = 0;
    int fineTotal = 0;

    for (final r in rentals) {
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
            // Header Switcher Tab: Ringkasan & Piutang vs Analitik Lanjutan
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMainTab = 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMainTab == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 18,
                                  color: _selectedMainTab == 0 ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ringkasan & Piutang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedMainTab == 0 ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMainTab = 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMainTab == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 18,
                                  color: _selectedMainTab == 1 ? Colors.white : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Analitik Bisnis',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _selectedMainTab == 1 ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _selectedMainTab == 1 ? Colors.amber.shade400 : Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_selectedMainTab == 0) ...[
              // ==========================================
              // TAB 1: RINGKASAN & PIUTANG (100% GRATIS)
              // ==========================================
              _buildFreeOverviewTab(
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
            ] else ...[
              // ==========================================
              // TAB 2: ANALITIK LANJUTAN (PREMIUM PREVIEW)
              // ==========================================
              _buildPremiumAnalyticsTab(context),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: RINGKASAN KEUANGAN & PIUTANG (GRATIS)
  // ==========================================
  Widget _buildFreeOverviewTab(
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Analisis Keterlambatan & Piutang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Text(
                'Fitur Terbuka (Gratis)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
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

        // Filter Periode
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Filter Rentang: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              _periodFilterChip('Semua Periode', ReportPeriodFilter.all),
              _periodFilterChip('Hari Ini', ReportPeriodFilter.today),
              _periodFilterChip('7 Hari Terakhir', ReportPeriodFilter.last7Days),
              _periodFilterChip('Bulan Ini', ReportPeriodFilter.thisMonth),
            ],
          ),
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
  // TAB 2: ANALITIK LANJUTAN (PREMIUM PREVIEW)
  // ==========================================
  Widget _buildPremiumAnalyticsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header Callout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade800, Colors.amber.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analitik Bisnis & Prediksi Rental',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Akses wawasan omzet, performa inventaris, dan estimasi laba bersih toko.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.amber.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showPremiumModal(context),
                child: const Text('Buka Fitur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // A. TREN OMZET (PREMIUM)
        _buildLockedCard(
          context,
          title: 'A. Tren Omzet & Pertumbuhan Penjualan',
          badgeText: 'PREMIUM',
          description: 'Grafik omzet harian, mingguan, bulanan, dan perbandingan pertumbuhan periode lalu.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period tabs & growth badge (Responsive LayoutBuilder prevents overflow on mobile)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  final chips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _analyticsChip('Harian', AnalyticsPeriodTab.daily),
                        _analyticsChip('Mingguan', AnalyticsPeriodTab.weekly),
                        _analyticsChip('Bulanan', AnalyticsPeriodTab.monthly),
                        _analyticsChip('Tahunan', AnalyticsPeriodTab.yearly),
                      ],
                    ),
                  );

                  final trendBadge = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          '+18.4% vs lalu',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        chips,
                        const SizedBox(height: 8),
                        trendBadge,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      chips,
                      trendBadge,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Mockup Bar Chart
              Container(
                height: 130,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _barColumn('Sen', 0.45, 'Rp 450rb'),
                    _barColumn('Sel', 0.35, 'Rp 350rb'),
                    _barColumn('Rab', 0.55, 'Rp 550rb'),
                    _barColumn('Kam', 0.70, 'Rp 700rb'),
                    _barColumn('Jum', 0.95, 'Rp 1.1jt', isPeak: true),
                    _barColumn('Sab', 1.00, 'Rp 1.4jt', isPeak: true),
                    _barColumn('Min', 0.60, 'Rp 600rb'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '* Data grafik di atas diperbarui secara berkala berdasarkan aktivitas rental kasir.',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // B. ANALISIS PERFORMA BARANG SEWAAN (PREMIUM)
        _buildLockedCard(
          context,
          title: 'B. Analisis Performa Barang Sewaan',
          badgeText: 'PREMIUM',
          description: 'Ketahui barang paling laris, omzet tertinggi, jarang disewa, serta tingkat utilisasi inventaris.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rankingRow('1', 'Tenda Camping 4P', '34x disewa', 'Omzet: Rp 2.550.000', Colors.amber.shade800),
              const Divider(height: 10, color: AppColors.border),
              _rankingRow('2', 'Sepatu Hiking Eiger', '28x disewa', 'Omzet: Rp 980.000', Colors.grey.shade700),
              const Divider(height: 10, color: AppColors.border),
              _rankingRow('3', 'Kompor Portable', '22x disewa', 'Omzet: Rp 550.000', Colors.brown.shade600),
              const Divider(height: 10, color: AppColors.border),
              _rankingRow('⚠️', 'Sarung Tangan Polar', '2x disewa (Jarang)', 'Rekomendasi Bundling', Colors.red.shade700),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 16, color: AppColors.info),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tingkat Utilisasi Inventaris Toko: 74% (Optimal)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // C. LAPORAN LABA & PENGELUARAN (PREMIUM)
        _buildLockedCard(
          context,
          title: 'C. Laporan Estimasi Laba & Pengeluaran',
          badgeText: 'PREMIUM',
          description: 'Ringkasan estimasi laba bersih setelah dikurangi biaya operasional & perawatan.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _financeRow('Pendapatan Omzet Sewa', 'Rp 4.080.000', Colors.green.shade800),
              const SizedBox(height: 4),
              _financeRow('Biaya Operasional & Cuci Alat', '- Rp 850.000', Colors.red.shade700),
              const SizedBox(height: 4),
              _financeRow('Biaya Maintenance & Servis', '- Rp 300.000', Colors.red.shade700),
              const Divider(height: 12, color: AppColors.border),
              _financeRow('Estimasi Laba Bersih', 'Rp 2.930.000', AppColors.primary, isBold: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Penting: Omzet berbeda dengan laba. Perhitungan laba bersih akurat memerlukan pencatatan pengeluaran operasional toko secara berkala.',
                        style: TextStyle(fontSize: 10, color: Colors.amber.shade900, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // D. ANALISIS PERFORMA KASIR (PREMIUM)
        _buildLockedCard(
          context,
          title: 'D. Analisis Performa Kasir',
          badgeText: 'PREMIUM',
          description: 'Audit jumlah transaksi dan kontribusi omzet per masing-masing staf kasir.',
          child: Column(
            children: [
              _cashierPerformanceRow('Budi Santoso (Kasir 1)', '24 Transaksi', 'Rp 2.850.000', 'Rata-rata: Rp 118.750 / trx'),
              const Divider(height: 10, color: AppColors.border),
              _cashierPerformanceRow('Siti Amelia (Kasir 2)', '18 Transaksi', 'Rp 1.230.000', 'Rata-rata: Rp 68.330 / trx'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // E. INSIGHT BISNIS & REKOMENDASI AI (PREMIUM)
        _buildLockedCard(
          context,
          title: 'E. Insight Bisnis Otomatis',
          badgeText: 'PREMIUM',
          description: 'Pola lonjakan pesanan, jam sibuk, dan rekomendasi penambahan stok.',
          child: Column(
            children: [
              _insightBullet(Icons.access_time, 'Jam Paling Ramai: 16:00 - 19:30 WIB (Pengambilan alat sebelum libur akhir pekan)'),
              const SizedBox(height: 6),
              _insightBullet(Icons.calendar_month, 'Hari Paling Ramai: Jumat & Sabtu (Puncak keberangkatan ekspedisi gunung)'),
              const SizedBox(height: 6),
              _insightBullet(Icons.lightbulb_outline, 'Rekomendasi: Tingkatkan stok Tenda 4P sebesar 20% untuk mengantisipasi peak season bulan depan.'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // F. EKSPOR LAPORAN (PREMIUM)
        _buildLockedCard(
          context,
          title: 'F. Ekspor Laporan Keuangan',
          badgeText: 'PREMIUM',
          description: 'Download laporan ke format dokumen resmi untuk akuntansi dan pembukuan.',
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Ekspor PDF Formal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onPressed: () => _showPremiumModal(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.table_chart, color: Colors.green, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Ekspor Excel (XLSX)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onPressed: () => _showPremiumModal(context),
                ),
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

  Widget _analyticsChip(String label, AnalyticsPeriodTab tab) {
    final isSelected = _analyticsTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _analyticsTab = tab),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _barColumn(String label, double fillFactor, String amount, {bool isPeak = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isPeak ? Colors.amber.shade900 : AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: 65 * fillFactor,
          decoration: BoxDecoration(
            color: isPeak ? Colors.amber.shade600 : AppColors.primary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _rankingRow(String rank, String name, String count, String subtext, Color color) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(rank, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
              Text(count, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text(subtext, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _financeRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 13 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textPrimary)),
        Text(value, style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _cashierPerformanceRow(String name, String txCount, String omzet, String avg) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(name[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(avg, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(omzet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
            Text(txCount, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _insightBullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.3)),
        ),
      ],
    );
  }

  // Card dengan overlay halus & lock icon untuk fitur Premium
  Widget _buildLockedCard(
    BuildContext context, {
    required String title,
    required String badgeText,
    required String description,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 11, color: Colors.amber.shade900),
                      const SizedBox(width: 3),
                      Text(
                        badgeText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            // Content child
            child,

            const SizedBox(height: 12),
            // Tombol "Lihat Fitur Premium"
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade900,
                  side: BorderSide(color: Colors.amber.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: Icon(Icons.workspace_premium, size: 15, color: Colors.amber.shade900),
                label: const Text('Lihat Fitur Premium Ini', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _showPremiumModal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.workspace_premium, color: Colors.amber.shade900, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Fitur Analitik Bisnis — Premium',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Dapatkan wawasan mendalam perkembangan omzet, tren musiman, utilisasi inventaris, dan audit performa staf kasir untuk memaksimalkan profit rental outdoor Anda.',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Keuntungan Paket Analitik Premium:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildModalBenefit(Icons.insights, 'Grafik omzet harian, mingguan, bulanan & tahunan'),
            _buildModalBenefit(Icons.bar_chart, 'Identifikasi barang paling laris & jarang disewa'),
            _buildModalBenefit(Icons.calculate_outlined, 'Laporan laba bersih & breakdown pengeluaran toko'),
            _buildModalBenefit(Icons.badge_outlined, 'Audit performa dan kontribusi transaksi per kasir'),
            _buildModalBenefit(Icons.picture_as_pdf, 'Ekspor laporan keuangan otomatis ke format PDF & Excel'),
            _buildModalBenefit(Icons.auto_awesome, 'Insight cerdas AI untuk prediksi jam sibuk & stok'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti & Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
        ],
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
}
