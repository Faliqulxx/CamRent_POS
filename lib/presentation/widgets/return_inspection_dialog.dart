import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/domain/calculator.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/receipt_preview_dialog.dart';

class ReturnInspectionDialog extends ConsumerStatefulWidget {
  final RentalModel rental;

  const ReturnInspectionDialog({super.key, required this.rental});

  static void show(BuildContext context, RentalModel rental) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReturnInspectionDialog(rental: rental),
    );
  }

  @override
  ConsumerState<ReturnInspectionDialog> createState() => _ReturnInspectionDialogState();
}

class _ReturnInspectionDialogState extends ConsumerState<ReturnInspectionDialog> {
  late List<RentalItemModel> _inspectedItems;
  final Map<String, TextEditingController> _noteControllers = {};
  bool _returnCollateral = true;
  PaymentMethod _paymentMethod = PaymentMethod.tunai;
  late final TextEditingController _cashPaidCtrl;
  int _cashPaid = 0;
  bool _hasInitializedCashPaid = false;

  @override
  void initState() {
    super.initState();
    _cashPaidCtrl = TextEditingController();
    _inspectedItems = widget.rental.items.map((it) {
      return it.copyWith(
        returnedQty: it.qty,
        condition: ItemCondition.baik,
      );
    }).toList();

    for (final it in widget.rental.items) {
      _noteControllers[it.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _cashPaidCtrl.dispose();
    for (final ctrl in _noteControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final settings = appState.settings;

    // Hitung denda telat
    int autoLateFee = 0;
    final overdueDays = widget.rental.overdueDays;
    if (overdueDays > 0) {
      for (final it in _inspectedItems) {
        autoLateFee += RentalCalculationEngine.calculateLateFeeForItem(
          dailyPrice: it.priceSnapshot,
          qty: it.qty,
          lateDays: overdueDays,
          ratePercent: settings.lateFeeRatePercent / 100.0,
        );
      }
    }

    // Hitung denda kondisi (kotor, rusak, hilang)
    int conditionFines = 0;
    final List<RentalFeeItem> appliedFees = [];

    if (autoLateFee > 0) {
      appliedFees.add(RentalFeeItem(
        id: 'fee_late',
        name: 'Denda Telat ($overdueDays hari)',
        type: 'telat',
        amount: autoLateFee,
        note: 'Terlambat dari jadwal ${DateFormatter.format(widget.rental.scheduledReturnDate)}',
      ));
    }

    for (final it in _inspectedItems) {
      if (it.fineAmount > 0) {
        conditionFines += it.fineAmount;
        appliedFees.add(RentalFeeItem(
          id: 'fee_${it.id}',
          name: '${it.nameSnapshot} (${it.condition.name.toUpperCase()})',
          type: it.condition.name,
          amount: it.fineAmount,
          note: it.conditionNote,
        ));
      }
    }

    final totalFines = autoLateFee + conditionFines;

    // Kalkulasi Settlement transparan PRD 3.5
    final depositAmount = widget.rental.deposit?.amount ?? 0;
    final settlement = RentalCalculationEngine.calculateSettlement(
      remainingRentalFee: widget.rental.remainingRentalFee,
      totalFines: totalFines,
      depositAmount: depositAmount,
    );

    // Inisialisasi default cash paid saat pertama kali ada sisa bayar
    if (!_hasInitializedCashPaid && settlement.remainingToPay > 0) {
      _cashPaid = settlement.remainingToPay;
      _cashPaidCtrl.text = settlement.remainingToPay.toString();
      _hasInitializedCashPaid = true;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 640,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pemeriksaan & Pengembalian Alat',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.rental.rentalNumber} • ${widget.rental.customer.name}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Status Keterlambatan
                    if (overdueDays > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Peringatan Keterlambatan: $overdueDays Hari',
                                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Jatuh tempo: ${DateFormatter.format(widget.rental.scheduledReturnDate)}. Otomatis dihitung denda telat: ${CurrencyFormatter.format(autoLateFee)}.',
                                    style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // LIST ITEM CEK KONDISI
                    const Text(
                      'Cek Kondisi Tiap Item:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_inspectedItems.length, (idx) {
                      final it = _inspectedItems[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: it.condition == ItemCondition.baik ? AppColors.border : AppColors.danger.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    it.nameSnapshot,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sewa: ${it.qty} unit',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Pilihan Kondisi Radio Buttons
                            Row(
                              children: ItemCondition.values.map((cond) {
                                final isSelected = it.condition == cond;
                                Color color = AppColors.success;
                                if (cond == ItemCondition.kotor) color = AppColors.warning;
                                if (cond == ItemCondition.rusak) color = AppColors.danger;
                                if (cond == ItemCondition.hilang) color = Colors.purple;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: InkWell(
                                      onTap: () {
                                        int fine = 0;
                                        if (cond == ItemCondition.kotor) fine = 25000;
                                        if (cond == ItemCondition.rusak) fine = 40000;
                                        if (cond == ItemCondition.hilang) fine = it.replacementPriceSnapshot;

                                        setState(() {
                                          _inspectedItems[idx] = it.copyWith(
                                            condition: cond,
                                            fineAmount: fine,
                                          );
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? color : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            cond.name.toUpperCase(),
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : AppColors.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            // Catatan & Input Denda jika tidak Baik
                            if (it.condition != ItemCondition.baik) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _noteControllers[it.id],
                                      decoration: InputDecoration(
                                        labelText: 'Catatan kondisi (${it.condition.name})',
                                        hintText: 'Misal: Tenda kotor lumpur / frame bengkok',
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        _inspectedItems[idx] = it.copyWith(conditionNote: val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: it.condition == ItemCondition.hilang ? 'Harga Ganti' : 'Denda (Rp)',
                                        prefixText: 'Rp ',
                                        isDense: true,
                                      ),
                                      controller: TextEditingController(text: it.fineAmount.toString()),
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                        setState(() {
                                          _inspectedItems[idx] = it.copyWith(fineAmount: parsed);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    // STATUS JAMINAN / DEPOSIT
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.rental.collateral != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Jaminan: ${widget.rental.collateral!.typeLabel}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keterangan: ${widget.rental.collateral!.note}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                'Serahkan kembali jaminan fisik ke pelanggan sekarang',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Jaminan tidak boleh ditandai kembali sebelum barang dicek dan pelunasan selesai.',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: _returnCollateral,
                              onChanged: (val) => setState(() => _returnCollateral = val ?? true),
                            ),
                          ] else if (widget.rental.deposit != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.monetization_on_outlined, color: AppColors.accent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Deposit Uang: ${CurrencyFormatter.format(widget.rental.deposit!.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Deposit akan dipotong otomatis untuk sisa pelunasan dan denda.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // KALKULASI SETTLEMENT (PRD 3.5)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ringkasan Tagihan & Penyelesaian:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const Divider(height: 16),
                          _row('Sisa Pelunasan Sewa', CurrencyFormatter.format(widget.rental.remainingRentalFee)),
                          if (autoLateFee > 0)
                            _row('Total Denda Telat', CurrencyFormatter.format(autoLateFee), isDanger: true),
                          if (conditionFines > 0)
                            _row('Total Denda Kerusakan/Kotor/Hilang', CurrencyFormatter.format(conditionFines), isDanger: true),
                          _row('TOTAL TAGIHAN', CurrencyFormatter.format(settlement.totalBill), isBold: true),
                          if (depositAmount > 0) ...[
                            const Divider(height: 12),
                            _row('Deposit Uang Dipakai', '-${CurrencyFormatter.format(settlement.depositUsed)}', isHighlight: true),
                            if (settlement.depositRefund > 0)
                              _row('KEMBALIAN DEPOSIT KE PELANGGAN', CurrencyFormatter.format(settlement.depositRefund), isSuccess: true, isBold: true),
                          ],
                          const Divider(height: 12),
                          _row(
                            'SISA DIBAYAR PELANGGAN',
                            CurrencyFormatter.format(settlement.remainingToPay),
                            isHighlight: true,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    // Metode Pelunasan (jika ada sisa bayar)
                    if (settlement.remainingToPay > 0) ...[
                      const SizedBox(height: 14),
                      const Text('Metode Pembayaran Pelunasan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: PaymentMethod.values.map((m) {
                          final isSel = _paymentMethod == m;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(m.name.toUpperCase()),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _paymentMethod = m;
                                    if (m == PaymentMethod.tunai && _cashPaid < settlement.remainingToPay) {
                                      _cashPaid = settlement.remainingToPay;
                                      _cashPaidCtrl.text = settlement.remainingToPay.toString();
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Input Nominal Uang Tunai Diterima & Kembalian
                      if (_paymentMethod == PaymentMethod.tunai) ...[
                        const SizedBox(height: 12),
                        // Presets Uang Tunai
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _quickCashChip('Uang Pas', settlement.remainingToPay),
                              if (settlement.remainingToPay < 50000)
                                _quickCashChip('50 rb', 50000),
                              if (settlement.remainingToPay <= 100000 && settlement.remainingToPay != 100000)
                                _quickCashChip('100 rb', 100000),
                              if (settlement.remainingToPay <= 150000 && settlement.remainingToPay != 150000)
                                _quickCashChip('150 rb', 150000),
                              if (settlement.remainingToPay <= 200000 && settlement.remainingToPay != 200000)
                                _quickCashChip('200 rb', 200000),
                              _quickCashChip('300 rb', 300000),
                              _quickCashChip('500 rb', 500000),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _cashPaidCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: 'Uang Tunai Diterima (Rp)',
                                  prefixText: 'Rp ',
                                  prefixStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 15,
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                  setState(() => _cashPaid = parsed);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Builder(
                                builder: (context) {
                                  final diff = _cashPaid - settlement.remainingToPay;
                                  final isMinus = diff < 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMinus ? AppColors.dangerLight : AppColors.successLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isMinus ? AppColors.danger : AppColors.success),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isMinus ? 'Uang Kurang' : 'Kembalian',
                                          style: TextStyle(
                                            color: isMinus ? AppColors.danger : AppColors.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            CurrencyFormatter.format(diff.abs()),
                                            style: TextStyle(
                                              color: isMinus ? AppColors.danger : AppColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    child: const Text('Batal'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Selesaikan & Cetak Struk Pelunasan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      onPressed: () {
                        if (settlement.remainingToPay > 0 &&
                            _paymentMethod == PaymentMethod.tunai &&
                            _cashPaid < settlement.remainingToPay) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Uang tunai yang diterima (${CurrencyFormatter.format(_cashPaid)}) kurang dari sisa tagihan (${CurrencyFormatter.format(settlement.remainingToPay)}).',
                              ),
                              backgroundColor: AppColors.danger,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        final finishedRental = ref.read(appStateProvider.notifier).processReturnSettlement(
                              rentalId: widget.rental.id,
                              updatedItems: _inspectedItems,
                              appliedFees: appliedFees,
                              settlement: settlement,
                              paymentMethod: _paymentMethod,
                              returnCollateralPhysical: _returnCollateral,
                            );

                        Navigator.pop(context); // Close inspection dialog

                        // Tampilkan struk pelunasan
                        ReceiptPreviewDialog.show(
                          context,
                          rental: finishedRental,
                          settings: appState.settings,
                          printerConfig: appState.printerConfig,
                          isReturnReceipt: true,
                          cashPaid: _paymentMethod == PaymentMethod.tunai ? _cashPaid : null,
                          cashChange: _paymentMethod == PaymentMethod.tunai ? (_cashPaid - settlement.remainingToPay) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCashChip(String label, int amount) {
    final isSelected = _cashPaid == amount;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label),
        backgroundColor: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onPressed: () {
          setState(() {
            _cashPaid = amount;
            _cashPaidCtrl.text = amount.toString();
          });
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, bool isHighlight = false, bool isDanger = false, bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 13 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isDanger
                  ? AppColors.danger
                  : isSuccess
                      ? AppColors.success
                      : isHighlight
                          ? AppColors.primary
                          : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
