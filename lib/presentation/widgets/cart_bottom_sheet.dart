import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/core/utils/date_formatter.dart';
import 'package:camprent_pos/data/models/rental_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/status_pill.dart';
import 'package:camprent_pos/presentation/widgets/receipt_preview_dialog.dart';
import 'package:camprent_pos/presentation/widgets/customer_selector_dialog.dart';

class CartBottomSheet extends ConsumerStatefulWidget {
  const CartBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CartBottomSheet(),
    );
  }

  @override
  ConsumerState<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends ConsumerState<CartBottomSheet> {
  final TextEditingController _collateralNoteCtrl = TextEditingController();
  final TextEditingController _depositCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _cashPaidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final form = ref.read(appStateProvider).newRentalForm;
    _collateralNoteCtrl.text = form.collateralNote;
    _depositCtrl.text = form.depositAmount.toString();
    _discountCtrl.text = form.discount > 0 ? form.discount.toString() : '';
    _cashPaidCtrl.text = form.cashPaid > 0 ? form.cashPaid.toString() : '';
  }

  @override
  void dispose() {
    _collateralNoteCtrl.dispose();
    _depositCtrl.dispose();
    _discountCtrl.dispose();
    _cashPaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final form = appState.newRentalForm;
    final totals = form.totals;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sewa Baru (Walk-in POS)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${form.cartItems.length} Item • Durasi ${form.durationDays} Hari',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (form.cartItems.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Kosongkan', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          ref.read(appStateProvider.notifier).clearCart();
                        },
                      ),
                  ],
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
                  // SECTION 1: PELANGGAN
                  _buildSectionCard(
                    title: '1. Data Pelanggan',
                    icon: Icons.person_outline,
                    action: TextButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: Text(form.selectedCustomer == null ? 'Pilih / Tambah' : 'Ganti'),
                      onPressed: () {
                        CustomerSelectorDialog.show(context);
                      },
                    ),
                    child: form.selectedCustomer == null
                        ? InkWell(
                            onTap: () => CustomerSelectorDialog.show(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.person_add_alt, color: AppColors.accent),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Belum ada pelanggan dipilih. Klik untuk mencari atau tambah baru.',
                                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: form.selectedCustomer!.isBlacklisted ? AppColors.dangerLight : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: form.selectedCustomer!.isBlacklisted ? AppColors.danger : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: form.selectedCustomer!.isBlacklisted ? AppColors.danger : AppColors.primary,
                                      child: Text(
                                        form.selectedCustomer!.name[0],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  form.selectedCustomer!.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (form.selectedCustomer!.isBlacklisted)
                                                StatusPill.blacklist(),
                                            ],
                                          ),
                                          Text(
                                            'WA: ${form.selectedCustomer!.phone}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (form.selectedCustomer!.isBlacklisted) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning, color: AppColors.danger, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Alasan: ${form.selectedCustomer!.blacklistReason ?? "Pernah bermasalah"} (Perlu persetujuan Owner)',
                                            style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // SECTION 2: TANGGAL SEWA
                  _buildSectionCard(
                    title: '2. Periode Sewa',
                    icon: Icons.calendar_today_outlined,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _datePickerTile(
                                label: 'Tgl Ambil',
                                date: form.pickupDate,
                                onTap: () => _pickDate(isPickup: true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 18),
                            ),
                            Expanded(
                              child: _datePickerTile(
                                label: 'Tgl Kembali',
                                date: form.returnDate,
                                onTap: () => _pickDate(isPickup: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick duration chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [1, 2, 3, 4, 5, 7].map((days) {
                              final isSelected = form.durationDays == days;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text('$days Hari'),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) {
                                    final newRet = form.pickupDate.add(Duration(days: days));
                                    ref.read(appStateProvider.notifier).updateRentalDates(form.pickupDate, newRet);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SECTION 3: ITEM DI KERANJANG
                  _buildSectionCard(
                    title: '3. Alat Disewa',
                    icon: Icons.outdoor_grill_outlined,
                    child: form.cartItems.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.remove_shopping_cart_outlined, color: AppColors.textMuted, size: 36),
                                SizedBox(height: 6),
                                Text(
                                  'Keranjang masih kosong',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                Text(
                                  'Pilih alat dari katalog di layar utama',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: form.cartItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (ctx, idx) {
                              final ci = form.cartItems[idx];
                              int price = ci.item.dailyPrice;
                              int maxAvailable = ci.item.availableStock;
                              if (ci.selectedSize != null && ci.item.hasVariants) {
                                final v = ci.item.variants.where((v) => v.size == ci.selectedSize).firstOrNull;
                                if (v != null) {
                                  if (v.dailyPrice != null) price = v.dailyPrice!;
                                  maxAvailable = v.availableStock;
                                }
                              }
                              final subtotal = price * ci.qty * form.durationDays;

                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ci.item.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (ci.selectedSize != null) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blue.shade200),
                                                ),
                                                child: Text(
                                                  'Size ${ci.selectedSize}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${CurrencyFormatter.format(price)}/hari • Sisa: $maxAvailable',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(subtotal),
                                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Counter
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                                        color: AppColors.textSecondary,
                                        onPressed: () {
                                          ref.read(appStateProvider.notifier).updateCartItemQty(
                                                ci.item.id,
                                                ci.qty - 1,
                                                selectedSize: ci.selectedSize,
                                              );
                                        },
                                      ),
                                      Text(
                                        '${ci.qty}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 22),
                                        color: ci.qty >= maxAvailable ? AppColors.textMuted : AppColors.primary,
                                        onPressed: ci.qty >= maxAvailable
                                            ? null
                                            : () {
                                                ref.read(appStateProvider.notifier).updateCartItemQty(
                                                      ci.item.id,
                                                      ci.qty + 1,
                                                      selectedSize: ci.selectedSize,
                                                    );
                                              },
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 14),

                  // SECTION 4: JAMINAN & DEPOSIT (PRD 3.3)
                  _buildSectionCard(
                    title: '4. Jaminan / Deposit',
                    icon: Icons.security_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Toggle Jaminan vs Deposit
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref.read(appStateProvider.notifier).updateCollateral(useCollateral: true);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: form.useCollateral ? AppColors.primary.withOpacity(0.1) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: form.useCollateral ? AppColors.primary : AppColors.border,
                                      width: form.useCollateral ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.badge_outlined, color: form.useCollateral ? AppColors.primary : AppColors.textSecondary, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Jaminan Identitas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: form.useCollateral ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref.read(appStateProvider.notifier).updateCollateral(useCollateral: false);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !form.useCollateral ? AppColors.accent.withOpacity(0.1) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !form.useCollateral ? AppColors.accent : AppColors.border,
                                      width: !form.useCollateral ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.monetization_on_outlined, color: !form.useCollateral ? AppColors.accent : AppColors.textSecondary, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Deposit Uang (Wajib)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: !form.useCollateral ? AppColors.accent : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Input Detail sesuai pilihan
                        if (form.useCollateral) ...[
                          Row(
                            children: [
                              DropdownButton<CollateralType>(
                                value: form.collateralType,
                                underline: const SizedBox(),
                                items: CollateralType.values.map((t) {
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Text(t.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (newType) {
                                  if (newType != null) {
                                    ref.read(appStateProvider.notifier).updateCollateral(
                                          useCollateral: true,
                                          type: newType,
                                        );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _collateralNoteCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Keterangan (mis. KTP a.n Dimas - 4 digit 1234)',
                                    hintStyle: TextStyle(fontSize: 12),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) {
                                    ref.read(appStateProvider.notifier).updateCollateral(
                                          useCollateral: true,
                                          note: val,
                                        );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '* Fisik jaminan dipegang toko selama sewa. Tidak ada foto jaminan.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _depositCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Nominal Deposit (Rp)',
                                    prefixText: 'Rp ',
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                    ref.read(appStateProvider.notifier).updateCollateral(
                                          useCollateral: false,
                                          depositAmount: parsed,
                                        );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '* Dipakai menutup tagihan saat pengembalian, sisanya dikembalikan.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SECTION 5: DISKON & PEMBAYARAN DP (PRD 3.2)
                  _buildSectionCard(
                    title: '5. Pembayaran DP',
                    icon: Icons.payments_outlined,
                    child: Column(
                      children: [
                        // Diskon
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _discountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Diskon (Opsional)',
                                  prefixText: 'Rp ',
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                  ref.read(appStateProvider.notifier).updatePaymentDetails(discount: parsed);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // DP % Choice (50% vs 100% Lunas)
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 50, label: Text('DP 50%')),
                                ButtonSegment(value: 100, label: Text('Lunas')),
                              ],
                              selected: {form.dpPercentage},
                              onSelectionChanged: (set) {
                                ref.read(appStateProvider.notifier).updatePaymentDetails(dpPercentage: set.first);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Payment Methods
                        Row(
                          children: PaymentMethod.values.map((method) {
                            final isSel = form.paymentMethod == method;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(appStateProvider.notifier).updatePaymentDetails(method: method);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isSel ? AppColors.primary : AppColors.border),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      method.name.toUpperCase(),
                                      style: TextStyle(
                                        color: isSel ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Quick Cash Buttons if Tunai
                        if (form.paymentMethod == PaymentMethod.tunai) ...[
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _quickCashChip('Uang Pas', form.totalToPayNow),
                                _quickCashChip('50 rb', 50000),
                                _quickCashChip('100 rb', 100000),
                                _quickCashChip('200 rb', 200000),
                                _quickCashChip('300 rb', 300000),
                                _quickCashChip('500 rb', 500000),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cashPaidCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Uang Diterima',
                                    prefixText: 'Rp ',
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                    ref.read(appStateProvider.notifier).updatePaymentDetails(cashPaid: parsed);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Builder(
                                builder: (context) {
                                  final isMinus = form.cashChange < 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMinus ? AppColors.dangerLight : AppColors.successLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isMinus ? AppColors.danger : AppColors.success),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMinus ? 'Kurang' : 'Kembalian',
                                          style: TextStyle(
                                            color: isMinus ? AppColors.danger : AppColors.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(form.cashChange),
                                          style: TextStyle(
                                            color: isMinus ? AppColors.danger : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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

                  const SizedBox(height: 14),

                  // RINGKASAN BIAYA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Subtotal Sewa', CurrencyFormatter.format(totals.subtotal)),
                        if (totals.discount > 0)
                          _summaryRow('Diskon', '-${CurrencyFormatter.format(totals.discount)}', isNegative: true),
                        _summaryRow('Total Biaya Sewa', CurrencyFormatter.format(totals.totalSewa), isBold: true),
                        const Divider(height: 16),
                        _summaryRow(
                          form.dpPercentage == 100 ? 'Pelunasan (Lunas)' : 'Wajib Bayar Sekarang (DP ${form.dpPercentage}%)',
                          CurrencyFormatter.format(totals.minDp),
                          isHighlight: true,
                        ),
                        if (!form.useCollateral)
                          _summaryRow('+ Deposit Uang', CurrencyFormatter.format(form.depositAmount)),
                        _summaryRow('Sisa Pelunasan Nanti', CurrencyFormatter.format(totals.sisaSewa)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Checkout Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total DP / Bayar:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      CurrencyFormatter.format(totals.minDp + (!form.useCollateral ? form.depositAmount : 0)),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: form.isValidToSubmit ? AppColors.primary : AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        form.paymentMethod == PaymentMethod.tunai && form.cashChange < 0
                            ? 'Uang Kurang (${CurrencyFormatter.format(form.cashChange)})'
                            : 'Simpan & Cetak Struk',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    onPressed: !form.isValidToSubmit
                        ? null
                        : () {
                            final savedRental = ref.read(appStateProvider.notifier).submitNewRental();
                            Navigator.pop(context); // Close bottom sheet

                            if (savedRental != null) {
                              // Tampilkan dialog cetak struk otomatis
                              ReceiptPreviewDialog.show(
                                context,
                                rental: savedRental,
                                settings: appState.settings,
                                printerConfig: appState.printerConfig,
                              );
                            }
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? action,
    required Widget child,
  }) {
    return Container(
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  DateFormatter.format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCashChip(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade100,
        onPressed: () {
          _cashPaidCtrl.text = amount.toString();
          ref.read(appStateProvider.notifier).updatePaymentDetails(cashPaid: amount);
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isHighlight = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHighlight ? 13 : 12,
                fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? AppColors.primary
                  : isNegative
                      ? AppColors.danger
                      : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isPickup}) async {
    final form = ref.read(appStateProvider).newRentalForm;
    final initial = isPickup ? form.pickupDate : form.returnDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      if (isPickup) {
        final newReturn = picked.isAfter(form.returnDate) ? picked.add(const Duration(days: 1)) : form.returnDate;
        ref.read(appStateProvider.notifier).updateRentalDates(picked, newReturn);
      } else {
        final newPickup = picked.isBefore(form.pickupDate) ? picked : form.pickupDate;
        ref.read(appStateProvider.notifier).updateRentalDates(newPickup, picked);
      }
    }
  }
}
