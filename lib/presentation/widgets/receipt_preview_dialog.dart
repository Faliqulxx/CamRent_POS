import 'package:flutter/material.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/data/models/printer_model.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  final RentalModel rental;
  final StoreSettingsModel settings;
  final PrinterConfigModel printerConfig;
  final bool isReturnReceipt;
  final bool isCopy;
  final int? cashPaid;
  final int? cashChange;

  const ReceiptPreviewDialog({
    super.key,
    required this.rental,
    required this.settings,
    required this.printerConfig,
    this.isReturnReceipt = false,
    this.isCopy = false,
    this.cashPaid,
    this.cashChange,
  });

  static void show(
    BuildContext context, {
    required RentalModel rental,
    required StoreSettingsModel settings,
    required PrinterConfigModel printerConfig,
    bool isReturnReceipt = false,
    bool isCopy = false,
    int? cashPaid,
    int? cashChange,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptPreviewDialog(
        rental: rental,
        settings: settings,
        printerConfig: printerConfig,
        isReturnReceipt: isReturnReceipt,
        isCopy: isCopy,
        cashPaid: cashPaid,
        cashChange: cashChange,
      ),
    );
  }

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  late PaperWidth _selectedWidth;

  @override
  void initState() {
    super.initState();
    _selectedWidth = widget.printerConfig.paperWidth;
  }

  @override
  Widget build(BuildContext context) {
    final is80mm = _selectedWidth == PaperWidth.width80mm;
    final paperDisplayWidth = is80mm ? 360.0 : 300.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Bar with Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pratinjau Struk Thermal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle 58mm / 80mm
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedWidth = PaperWidth.width58mm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: !_is80mm ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('58mm', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedWidth = PaperWidth.width80mm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _is80mm ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('80mm', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Scrollable Thermal Paper Canvas
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                width: paperDisplayWidth,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Copy Watermark if copy
                    if (widget.isCopy)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '*** SALINAN STRUK ***',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ),

                    // Thermal Logo (Monochrome filter)
                    if (widget.printerConfig.showLogo) ...[
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: Image.asset(
                          widget.printerConfig.effectiveLogoAsset,
                          width: widget.printerConfig.logoDisplayWidth,
                          height: widget.printerConfig.logoDisplayWidth * 0.7,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Store Info
                    Text(
                      widget.settings.storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (widget.settings.subHeader.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.settings.subHeader,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      widget.settings.storeAddress,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      'Telp/WA: ${widget.settings.storePhone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _dashedDivider(),

                    // Receipt Title
                    Text(
                      widget.isReturnReceipt ? 'BUKTI PENGEMBALIAN & PELUNASAN' : 'BUKTI SEWA ALAT OUTDOOR',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _dashedDivider(),

                    // Meta Information
                    _metaRow('No. Transaksi', widget.rental.rentalNumber),
                    _metaRow('Waktu Cetak', DateFormatter.formatDateTime(DateTime.now())),
                    _metaRow('Kasir', widget.rental.cashierName),
                    _metaRow('Pelanggan', widget.rental.customer.name),
                    _metaRow('No. WA', widget.rental.customer.phone),
                    _metaRow('Tgl Ambil', DateFormatter.format(widget.rental.pickupDate)),
                    _metaRow('Tgl Kembali', DateFormatter.format(widget.rental.scheduledReturnDate)),
                    _metaRow('Durasi Sewa', '${widget.rental.durationDays} Hari'),
                    _dashedDivider(),

                    // Items Table
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ITEM / HARGA', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('TOTAL', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...widget.rental.items.map((it) {
                      final itemTotal = it.priceSnapshot * it.qty * widget.rental.durationDays;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.nameSnapshot,
                              style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '  ${it.qty}x @${CurrencyFormatter.format(it.priceSnapshot)} x ${widget.rental.durationDays}hr',
                                  style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black87),
                                ),
                                Text(
                                  CurrencyFormatter.format(itemTotal),
                                  style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                                ),
                              ],
                            ),
                            if (it.condition != ItemCondition.baik)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 1),
                                child: Text(
                                  '[Kondisi: ${it.condition.name.toUpperCase()}] ${it.conditionNote}',
                                  style: const TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    _dashedDivider(),

                    // Subtotal & Discounts
                    _summaryRow('Subtotal Sewa', CurrencyFormatter.format(widget.rental.subtotal)),
                    if (widget.rental.discount > 0)
                      _summaryRow('Diskon', '-${CurrencyFormatter.format(widget.rental.discount)}'),
                    _summaryRow('TOTAL SEWA', CurrencyFormatter.format(widget.rental.totalSewa), isBold: true),
                    _summaryRow('DP Dibayar (Awal)', CurrencyFormatter.format(widget.rental.dpPaid)),
                    _summaryRow('Sisa Pelunasan', CurrencyFormatter.format(widget.rental.remainingRentalFee)),

                    // Collateral / Deposit Info
                    _dashedDivider(),
                    if (widget.rental.collateral != null) ...[
                      _summaryRow('Jaminan Fisik', widget.rental.collateral!.typeLabel, isBold: true),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ket: ${widget.rental.collateral!.note}',
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                      _summaryRow(
                        'Status Jaminan',
                        widget.rental.collateral!.isReturned ? 'SUDAH DIKEMBALIKAN' : 'DIPEGANG TOKO',
                        isBold: true,
                      ),
                    ] else if (widget.rental.deposit != null) ...[
                      _summaryRow('Deposit Uang', CurrencyFormatter.format(widget.rental.deposit!.amount), isBold: true),
                      if (widget.rental.deposit!.usedAmount > 0)
                        _summaryRow('Deposit Dipakai', CurrencyFormatter.format(widget.rental.deposit!.usedAmount)),
                      if (widget.rental.deposit!.refundedAmount > 0)
                        _summaryRow('Kembalian Deposit', CurrencyFormatter.format(widget.rental.deposit!.refundedAmount), isBold: true),
                    ],

                    // Fees (if Return Receipt)
                    if (widget.isReturnReceipt && widget.rental.fees.isNotEmpty) ...[
                      _dashedDivider(),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('RINCIAN DENDA & BIAYA:', style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 2),
                      ...widget.rental.fees.map((f) => _summaryRow(f.name, CurrencyFormatter.format(f.amount))),
                      _summaryRow('TOTAL DENDA', CurrencyFormatter.format(widget.rental.totalFees), isBold: true),
                    ],

                    // Tunai Diterima & Kembalian (jika ada transaksi tunai)
                    if (widget.cashPaid != null && widget.cashPaid! > 0) ...[
                      _dashedDivider(),
                      _summaryRow('Tunai Diterima', CurrencyFormatter.format(widget.cashPaid!)),
                      _summaryRow('Kembalian', CurrencyFormatter.format(widget.cashChange ?? 0), isBold: true),
                    ],

                    // Terms & Conditions (if enabled)
                    if (widget.printerConfig.showTerms) ...[
                      _dashedDivider(),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'KETENTUAN SEWA SINGKAT:',
                          style: TextStyle(fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '1. Jaminan fisik/deposit ditahan selama masa sewa.\n2. Cek kelengkapan & kondisi alat sebelum meninggalkan toko.\n3. Keterlambatan sewa dikenakan denda sesuai tarif harian.\n4. Alat kotor/rusak/hilang dikenakan biaya penggantian.',
                          style: TextStyle(fontFamily: 'Courier', fontSize: 8.5, color: Colors.black87),
                        ),
                      ),
                    ],

                    _dashedDivider(),

                    // Footer message
                    Text(
                      widget.settings.receiptFooter,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 9,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '*** TERIMA KASIH & SALAM LESTARI ***',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Barcode / QR Code for fast scanner check-in (PRD return flow)
                    if (widget.printerConfig.showQrCode) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 38,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '|| | |||| | ||| || ||| |',
                          style: TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 18, letterSpacing: 4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '* ${widget.rental.rentalNumber} *',
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Zigzag tear bottom edge
                    _tearLine(),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Bagikan PDF')),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File struk PDF tersimpan dan siap dibagikan')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Cetak Sekarang')),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.primary,
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Terkirim ke Printer Thermal Bluetooth!'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _is80mm => _selectedWidth == PaperWidth.width80mm;

  Widget _dashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        _is80mm
            ? '------------------------------------------------'
            : '--------------------------------',
        style: const TextStyle(fontFamily: 'Courier', color: Colors.black38, fontSize: 11),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black54)),
          Text(value, style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: isBold ? 11 : 10,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: isBold ? 11 : 10,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tearLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _is80mm ? 24 : 18,
        (index) => Container(
          width: 8,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: Colors.black12,
        ),
      ),
    );
  }
}
