import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  const CloseShiftDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CloseShiftDialog(),
    );
  }

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  int? _actualCash;

  @override
  void initState() {
    super.initState();
    final activeShift = ref.read(appStateProvider).activeCashierShift;
    if (activeShift != null) {
      final expected = activeShift.expectedCash;
      _actualCash = expected;
      _actualCashController.text = expected.toString();
    }
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleConfirmClose() {
    if (_actualCash == null || _actualCash! < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan jumlah kas aktual fisik yang valid.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final activeShift = ref.read(appStateProvider).activeCashierShift;
    if (activeShift == null) return;

    final diff = _actualCash! - activeShift.expectedCash;
    if (diff != 0 && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap masukkan catatan penjelasan atas selisih kas fisik.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    ref.read(appStateProvider.notifier).closeShift(
          actualCash: _actualCash!,
          discrepancyNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shift kasir berhasil ditutup dan laporan telah direkonsiliasi.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShift = ref.watch(appStateProvider).activeCashierShift;
    if (activeShift == null) {
      return const AlertDialog(
        title: Text('Shift Tidak Aktif'),
        content: Text('Tidak ada shift kasir yang sedang berjalan.'),
      );
    }

    final expectedCash = activeShift.expectedCash;
    final actual = _actualCash ?? expectedCash;
    final diff = actual - expectedCash;

    final isMobile = MediaQuery.of(context).size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title & Close icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_outlined, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tutup Shift Kasir',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '${activeShift.cashierName} • Dimulai ${DateFormatter.formatTime(activeShift.startTime)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Rincian Arus Kas Shift
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRow('Modal Awal Kas', CurrencyFormatter.format(activeShift.initialCash)),
                    const SizedBox(height: 8),
                    _buildRow(
                      'Penerimaan Tunai (+)',
                      CurrencyFormatter.format(activeShift.totalCashPayments),
                      valueColor: AppColors.primary,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _buildRow(
                      'Pengeluaran Kas (-)',
                      CurrencyFormatter.format(activeShift.cashExpenses),
                      valueColor: activeShift.cashExpenses > 0 ? AppColors.danger : AppColors.textSecondary,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    _buildRow(
                      'Kas Diharapkan di Laci',
                      CurrencyFormatter.format(expectedCash),
                      isBold: true,
                      valueColor: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Non-cash summary badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 16, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Non-Tunai: Transfer ${CurrencyFormatter.format(activeShift.totalTransferPayments)} • QRIS ${CurrencyFormatter.format(activeShift.totalQrisPayments)} (${activeShift.totalTransactions} Transaksi)',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Input Kas Aktual
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Kas Fisik Aktual di Laci (Rp)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.flash_on, size: 14),
                    label: const Text('Isi Pas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _actualCash = expectedCash;
                        _actualCashController.text = expectedCash.toString();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _actualCashController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text('Rp', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  setState(() => _actualCash = parsed);
                },
              ),
              const SizedBox(height: 12),

              // Selisih Kas Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: diff == 0
                      ? const Color(0xFFF0FDF4)
                      : (diff > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: diff == 0
                        ? const Color(0xFFBBF7D0)
                        : (diff > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      diff == 0
                          ? Icons.check_circle
                          : (diff > 0 ? Icons.trending_up : Icons.warning_amber_rounded),
                      size: 20,
                      color: diff == 0
                          ? AppColors.success
                          : (diff > 0 ? AppColors.info : AppColors.danger),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diff == 0
                                ? 'Status: Kas Sesuai'
                                : (diff > 0 ? 'Status: Kas Lebih' : 'Status: Kas Kurang'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: diff == 0
                                  ? AppColors.success
                                  : (diff > 0 ? AppColors.info : AppColors.danger),
                            ),
                          ),
                          Text(
                            diff == 0
                                ? 'Jumlah kas fisik di laci pas dengan kas yang seharusnya.'
                                : 'Selisih kas fisik: ${diff > 0 ? '+' : ''}${CurrencyFormatter.format(diff)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: diff == 0
                                  ? Colors.green.shade800
                                  : (diff > 0 ? Colors.blue.shade900 : Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Catatan Kasir (jika terjadi selisih)
              Text(
                diff != 0 ? 'Catatan Kasir (Wajib Diisi)*' : 'Catatan Shift (Opsional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: diff != 0 ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: diff != 0
                      ? 'Tulis alasan selisih kas (misal: salah uang kembalian / pembulatan)...'
                      : 'Catatan operasional shift (jika ada)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.lock_clock, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Konfirmasi & Tutup Shift',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: _handleConfirmClose,
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

  Widget _buildRow(String label, String value, {Color? valueColor, bool isBold = false, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
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
