import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/printer_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class PrinterTestDialog extends StatelessWidget {
  const PrinterTestDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const PrinterTestDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final config = ref.watch(appStateProvider).printerConfig;
        final is80mm = config.paperWidth == PaperWidth.width80mm;
        final chars = is80mm ? 48 : 32;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hasil Uji Cetak Thermal Printer',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Thermal Test Paper Output
              Container(
                width: is80mm ? 360 : 300,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (config.showLogo) ...[
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: Image.asset(
                          config.effectiveLogoAsset,
                          width: config.logoDisplayWidth,
                          height: config.logoDisplayWidth * 0.7,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Text(
                      '*** UJI CETAK PRINTER THERMAL ***',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'CampRent POS • ESC/POS Adapter',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Waktu: ${DateFormatter.formatDateTime(DateTime.now())}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                    ),
                    Text(
                      'Perangkat: ${config.selectedPrinterName ?? "Default"}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                    ),
                    Text(
                      'Lebar: ${is80mm ? "80mm" : "58mm"} ($chars Karakter/Baris)',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Test line width ruler
                    Text(
                      is80mm
                          ? '123456789012345678901234567890123456789012345678'
                          : '12345678901234567890123456789012',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.blueGrey),
                    ),
                    Text(
                      is80mm
                          ? '================================================'
                          : '================================',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                    ),
                    const SizedBox(height: 6),

                    // Font sizes preview
                    const Text('FONT SIZE: NORMAL', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                    const Text('FONT SIZE: BOLD', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                    const Text('ALIGN: CENTER', style: TextStyle(fontFamily: 'Courier', fontSize: 11)),
                    const SizedBox(height: 6),

                    // Sample Table Layout
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tenda Dome 4P x1', style: TextStyle(fontFamily: 'Courier', fontSize: 10)),
                        Text('Rp 100.000', style: TextStyle(fontFamily: 'Courier', fontSize: 10)),
                      ],
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Carrier 60L  x1', style: TextStyle(fontFamily: 'Courier', fontSize: 10)),
                        Text('Rp  70.000', style: TextStyle(fontFamily: 'Courier', fontSize: 10)),
                      ],
                    ),
                    Text(
                      is80mm
                          ? '------------------------------------------------'
                          : '--------------------------------',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL TEST', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Rp 170.000', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Barcode test simulation
                    Container(
                      height: 35,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '|| | |||| | ||| || ||| |',
                        style: TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 20, letterSpacing: 4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text('RNT-TEST-0001', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                    const SizedBox(height: 12),

                    const Text(
                      'STATUS: TES CETAK SUKSES LENGKAP',
                      style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Bottom Button
              Container(
                width: is80mm ? 360 : 300,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Tutup & Selesai'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
