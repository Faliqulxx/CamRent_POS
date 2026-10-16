import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class OpenShiftView extends ConsumerStatefulWidget {
  const OpenShiftView({super.key});

  @override
  ConsumerState<OpenShiftView> createState() => _OpenShiftViewState();
}

class _OpenShiftViewState extends ConsumerState<OpenShiftView> {
  final TextEditingController _cashController = TextEditingController(text: '200000');
  int _initialCash = 200000;

  final List<int> _quickPresets = [100000, 200000, 300000, 500000];

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _setPreset(int amount) {
    setState(() {
      _initialCash = amount;
      _cashController.text = amount.toString();
    });
  }

  void _handleStartShift() {
    if (_initialCash < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modal awal kas tidak boleh bernilai negatif.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    ref.read(appStateProvider.notifier).openShift(_initialCash);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift berhasil dibuka dengan modal awal ${CurrencyFormatter.format(_initialCash)}. Selamat bertugas!',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final cashierName = appState.activeCashierName;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 3,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Icon & Greeting
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Buka Shift Kasir',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Halo, $cashierName 👋\nAnda belum membuka shift kasir hari ini. Masukkan modal awal kas fisik di laci sebelum memulai operasional transaksi rental.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info Alert Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hitung uang fisik di laci kasir dengan teliti. Modal awal ini akan menjadi saldo awal untuk rekonsiliasi kas saat tutup shift.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input Modal Awal Kas
                    const Text(
                      'Modal Awal Kas Fisik (Rp)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(
                            'Rp',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        setState(() => _initialCash = parsed);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Quick Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPresets.map((amount) {
                        final isSelected = _initialCash == amount;
                        return ChoiceChip(
                          label: Text(CurrencyFormatter.format(amount)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (_) => _setPreset(amount),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Mulai Shift Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'Mulai Shift Sekarang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _handleStartShift,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
