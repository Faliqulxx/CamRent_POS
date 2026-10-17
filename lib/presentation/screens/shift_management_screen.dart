import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  String _searchQuery = '';
  ShiftStatus? _selectedStatus;
  int _dateFilter = 0; // 0 = Semua, 1 = Hari Ini, 2 = 7 Hari Terakhir

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final allShifts = appState.shifts;

    // Summary Metrics
    final activeCashierNames = allShifts
        .where((s) => s.status == ShiftStatus.sedangBerjalan)
        .map((s) => s.cashierName.toLowerCase().trim())
        .toSet();
    final activeCount = activeCashierNames.length;
    final unopenCount = allShifts.where((s) => s.status == ShiftStatus.belumBuka).length;
    final completedCount = allShifts.where((s) => s.status == ShiftStatus.selesai).length;
    final totalCash = allShifts.fold<int>(0, (sum, s) => sum + s.totalCashPayments);
    final totalDifference = allShifts
        .where((s) => s.status == ShiftStatus.selesai && s.cashDifference != null)
        .fold<int>(0, (sum, s) => sum + s.cashDifference!);

    // Filter shifts
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final filteredShifts = allShifts.where((s) {
      // Search
      final q = _searchQuery.toLowerCase().trim();
      if (q.isNotEmpty &&
          !s.cashierName.toLowerCase().contains(q) &&
          !s.cashierEmail.toLowerCase().contains(q)) {
        return false;
      }

      // Status
      if (_selectedStatus != null && s.status != _selectedStatus) {
        return false;
      }

      // Date
      if (_dateFilter == 1) {
        final shiftDate = DateTime(s.date.year, s.date.month, s.date.day);
        if (!shiftDate.isAtSameMomentAs(today)) return false;
      } else if (_dateFilter == 2) {
        if (s.date.isBefore(sevenDaysAgo)) return false;
      }

      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Manajemen Shift Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Monitoring aktivitas shift kasir & audit rekonsiliasi kas',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 5 Metric Cards (Section 3)
            _buildSummaryMetrics(
              isMobile: isMobile,
              activeCount: activeCount,
              unopenCount: unopenCount,
              completedCount: completedCount,
              totalCash: totalCash,
              totalDifference: totalDifference,
            ),
            const SizedBox(height: 20),

            // Search & Filter Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari kasir (nama atau email)...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        _buildStatusFilterChip('Semua', null),
                        _buildStatusFilterChip('Sedang Berjalan', ShiftStatus.sedangBerjalan),
                        _buildStatusFilterChip('Selesai', ShiftStatus.selesai),
                        _buildStatusFilterChip('Belum Buka Shift', ShiftStatus.belumBuka),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Tanggal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        _buildDateFilterChip('Semua', 0),
                        _buildDateFilterChip('Hari Ini', 1),
                        _buildDateFilterChip('7 Hari Terakhir', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Aktivitas Shift (${filteredShifts.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                Text(
                  'Sistem Manajemen Kasir',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Shifts List / Cards
            if (filteredShifts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.manage_history, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Tidak ada riwayat shift yang sesuai filter.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredShifts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final shift = filteredShifts[idx];
                  return _buildShiftCard(shift, isMobile);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics({
    required bool isMobile,
    required int activeCount,
    required int unopenCount,
    required int completedCount,
    required int totalCash,
    required int totalDifference,
  }) {
    final cards = [
      _MetricItem(
        title: 'Kasir Aktif Shift',
        value: '$activeCount Kasir',
        icon: Icons.play_circle_outline,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
      _MetricItem(
        title: 'Belum Buka Shift',
        value: '$unopenCount Kasir',
        icon: Icons.pause_circle_outline,
        color: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
      ),
      _MetricItem(
        title: 'Shift Selesai',
        value: '$completedCount Shift',
        icon: Icons.task_alt,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _MetricItem(
        title: 'Total Tunai Shift',
        value: CurrencyFormatter.format(totalCash),
        icon: Icons.payments_outlined,
        color: AppColors.primary,
        bgColor: const Color(0xFFF0FDF4),
      ),
      _MetricItem(
        title: 'Total Selisih Kas',
        value: '${totalDifference > 0 ? "+" : ""}${CurrencyFormatter.format(totalDifference)}',
        icon: totalDifference == 0
            ? Icons.check_circle_outline
            : (totalDifference > 0 ? Icons.trending_up : Icons.warning_amber_rounded),
        color: totalDifference == 0
            ? const Color(0xFF16A34A)
            : (totalDifference > 0 ? const Color(0xFF2563EB) : AppColors.danger),
        bgColor: totalDifference == 0
            ? const Color(0xFFF0FDF4)
            : (totalDifference > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2)),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 105,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(width: 175, child: cards[i]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) {
            final cardWidth = (constraints.maxWidth - (12 * 4)) / 5;
            return SizedBox(
              width: cardWidth.clamp(170, 260),
              child: c,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String label, ShiftStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _selectedStatus = status),
    );
  }

  Widget _buildDateFilterChip(String label, int val) {
    final isSelected = _dateFilter == val;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _dateFilter = val),
    );
  }

  Widget _buildShiftCard(CashierShiftModel shift, bool isMobile) {
    final diff = shift.cashDifference;
    final ds = shift.differenceStatus;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showShiftDetail(context, shift),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Kasir + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Text(
                      shift.cashierName.isNotEmpty ? shift.cashierName[0].toUpperCase() : 'K',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.cashierName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          shift.cashierEmail,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _buildShiftStatusBadge(shift.status),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Grid of columns: Tanggal, Waktu Mulai-Selesai, Modal Awal, Transaksi, Kas Diharapkan, Kas Aktual, Selisih
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _buildColItem(
                    'Tanggal',
                    DateFormatter.format(shift.date),
                    icon: Icons.calendar_today_outlined,
                  ),
                  _buildColItem(
                    'Waktu Mulai - Selesai',
                    shift.status == ShiftStatus.belumBuka
                        ? 'Belum Mulai'
                        : '${DateFormatter.formatTime(shift.startTime)} - ${shift.endTime != null ? DateFormatter.formatTime(shift.endTime!) : "Sekarang"}',
                    icon: Icons.access_time,
                  ),
                  _buildColItem(
                    'Modal Awal',
                    CurrencyFormatter.format(shift.initialCash),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _buildColItem(
                    'Total Transaksi',
                    '${shift.totalTransactions} Transaksi (${CurrencyFormatter.format(shift.totalCashPayments)} Tunai)',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _buildColItem(
                    'Kas Diharapkan',
                    shift.status == ShiftStatus.belumBuka ? '-' : CurrencyFormatter.format(shift.expectedCash),
                    icon: Icons.calculate_outlined,
                    isBold: true,
                  ),
                  _buildColItem(
                    'Kas Aktual',
                    shift.actualCash != null ? CurrencyFormatter.format(shift.actualCash!) : '-',
                    icon: Icons.point_of_sale_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selisih Kas & Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Selisih badge
                  Expanded(
                    child: shift.status == ShiftStatus.selesai && ds != null
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: _buildDifferenceBadge(ds, diff!),
                          )
                        : (shift.status == ShiftStatus.sedangBerjalan
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.autorenew, size: 13, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Shift Sedang Berjalan',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const Text(
                                'Menunggu Pembukaan Shift',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Tutup Shift (Khusus shift yang sedang berjalan)
                  if (shift.status == ShiftStatus.sedangBerjalan) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined, size: 14),
                      label: const Text('Tutup Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmCloseShift(context, shift),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Detail Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                    label: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showShiftDetail(context, shift),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColItem(String label, String value, {IconData? icon, bool isBold = false}) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStatusBadge(ShiftStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case ShiftStatus.sedangBerjalan:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        label = 'Sedang Berjalan';
        icon = Icons.play_circle_fill;
        break;
      case ShiftStatus.selesai:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'Selesai';
        icon = Icons.check_circle;
        break;
      case ShiftStatus.belumBuka:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        label = 'Belum Buka Shift';
        icon = Icons.pause_circle_filled;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceBadge(CashDifferenceStatus status, int diff) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case CashDifferenceStatus.sesuai:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        text = 'Kas Sesuai (Rp 0)';
        icon = Icons.check_circle;
        break;
      case CashDifferenceStatus.lebih:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        text = 'Kas Lebih (+${CurrencyFormatter.format(diff)})';
        icon = Icons.trending_up;
        break;
      case CashDifferenceStatus.kurang:
        bg = const Color(0xFFFEF2F2);
        fg = AppColors.danger;
        text = 'Kas Kurang (${CurrencyFormatter.format(diff)})';
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  void _showShiftDetail(BuildContext context, CashierShiftModel shift) {
    showDialog(
      context: context,
      builder: (ctx) => _ShiftDetailDialog(
        shift: shift,
        onCloseShift: () => _confirmCloseShift(context, shift),
      ),
    );
  }

  Future<void> _confirmCloseShift(BuildContext context, CashierShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Tutup Shift Kasir?'),
          ],
        ),
        content: Text(
          'Tutup shift untuk "${shift.cashierName}"?\n'
          'Waktu Mulai: ${DateFormatter.formatTime(shift.startTime)} • Modal Awal: ${CurrencyFormatter.format(shift.initialCash)}\n\n'
          'Kas akhir fisik akan disamakan dengan kas yang diharapkan (${CurrencyFormatter.format(shift.expectedCash)}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tutup Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(appStateProvider.notifier).closeShiftById(
        shiftId: shift.id,
        actualCash: shift.expectedCash,
        discrepancyNote: 'Ditutup secara manual oleh Owner dari menu monitoring shift.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shift kasir "${shift.cashierName}" berhasil ditutup.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Detail Laporan Shift oleh Owner (Section 4)
class _ShiftDetailDialog extends StatelessWidget {
  final CashierShiftModel shift;
  final VoidCallback? onCloseShift;

  const _ShiftDetailDialog({required this.shift, this.onCloseShift});

  @override
  Widget build(BuildContext context) {
    final diff = shift.cashDifference;
    final ds = shift.differenceStatus;
    final isMobile = MediaQuery.of(context).size.width < 540;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Dialog
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pemeriksaan Laporan Shift',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Audit rekonsiliasi kasir CampRent POS',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Visual Status Banner (Kas Sesuai / Lebih / Kurang)
              if (shift.status == ShiftStatus.selesai && ds != null) ...[
                _buildVisualDifferenceBanner(ds, diff!),
                const SizedBox(height: 14),
              ] else if (shift.status == ShiftStatus.sedangBerjalan) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.autorenew, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shift sedang aktif berjalan. Rekonsiliasi kas final akan dihitung setelah kasir menutup shift.',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Identitas Kasir Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Identitas Kasir',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: shift.cashierName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              children: [
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: '(${shift.cashierEmail})',
                                  style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shift.status == ShiftStatus.belumBuka
                                ? 'Belum dibuka'
                                : 'Waktu: ${DateFormatter.formatTime(shift.startTime)} s/d ${shift.endTime != null ? DateFormatter.formatTime(shift.endTime!) : "Sekarang"} • Tanggal ${DateFormatter.format(shift.date)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Rincian Keuangan Shift Table
              const Text(
                'Ringkasan Arus Kas & Penerimaan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Modal Awal Kas', CurrencyFormatter.format(shift.initialCash)),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Penerimaan Tunai',
                      CurrencyFormatter.format(shift.totalCashPayments),
                      valueColor: AppColors.primary,
                      isBold: true,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow('Penerimaan Transfer Bank', CurrencyFormatter.format(shift.totalTransferPayments)),
                    const SizedBox(height: 6),
                    _buildDetailRow('Penerimaan QRIS', CurrencyFormatter.format(shift.totalQrisPayments)),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Pengeluaran Kas Tercatat',
                      CurrencyFormatter.format(shift.cashExpenses),
                      valueColor: shift.cashExpenses > 0 ? AppColors.danger : AppColors.textSecondary,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Total Omzet Masuk Shift',
                      CurrencyFormatter.format(shift.totalIncome),
                      isBold: true,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Kas Seharusnya Tersedia',
                      CurrencyFormatter.format(shift.expectedCash),
                      isBold: true,
                      valueColor: AppColors.primaryDark,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Kas Aktual (Hitungan Kasir)',
                      shift.actualCash != null ? CurrencyFormatter.format(shift.actualCash!) : '(Belum Ditutup)',
                      isBold: true,
                      valueColor: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    if (diff != null) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Selisih Kas Fisik',
                        '${diff > 0 ? "+" : ""}${CurrencyFormatter.format(diff)}',
                        isBold: true,
                        valueColor: diff == 0
                            ? AppColors.success
                            : (diff > 0 ? AppColors.info : AppColors.danger),
                        fontSize: 14,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Catatan Kasir ketika terjadi selisih
              if (shift.discrepancyNote != null && shift.discrepancyNote!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notes, size: 16, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Text(
                            'Catatan Kasir Saat Terjadi Selisih:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shift.discrepancyNote!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Notice frontend simulation
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Catatan Audit: Rekonsiliasi kas dicatat secara otomatis untuk transparansi pembukuan kasir & Owner toko.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
              // Tombol Tutup Shift (Owner Action)
              if (shift.status == ShiftStatus.sedangBerjalan && onCloseShift != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Tutup Shift Ini Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCloseShift!();
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cetak Ringkasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ringkasan Shift berhasil dikirim ke printer POS.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualDifferenceBanner(CashDifferenceStatus status, int diff) {
    Color bg;
    Color border;
    Color textCol;
    String title;
    String desc;
    IconData icon;

    switch (status) {
      case CashDifferenceStatus.sesuai:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        textCol = const Color(0xFF16A34A);
        title = 'STATUS REKONSILIASI: KAS SESUAI';
        desc = 'Kas aktual fisik di laci cocok 100% dengan total perhitungan sistem (Selisih: Rp 0).';
        icon = Icons.check_circle_outline;
        break;
      case CashDifferenceStatus.lebih:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        textCol = const Color(0xFF2563EB);
        title = 'STATUS REKONSILIASI: KAS LEBIH';
        desc = 'Kas aktual fisik di laci lebih besar +${CurrencyFormatter.format(diff)} dibanding perhitungan sistem.';
        icon = Icons.trending_up;
        break;
      case CashDifferenceStatus.kurang:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        textCol = AppColors.danger;
        title = 'STATUS REKONSILIASI: KAS KURANG';
        desc = 'Kas aktual fisik di laci mengalami kekurangan ${CurrencyFormatter.format(diff)} dibanding perhitungan sistem.';
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textCol, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textCol),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: textCol.withOpacity(0.9), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isBold = false, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
