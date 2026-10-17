import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/core/utils/currency_formatter.dart';
import 'package:camprent_pos/data/models/printer_model.dart';
import 'package:camprent_pos/data/models/settings_model.dart';
import 'package:camprent_pos/data/models/shift_model.dart';
import 'package:camprent_pos/data/services/supabase_service.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/printer_test_dialog.dart';
import 'package:camprent_pos/presentation/screens/shift_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _subHeaderCtrl;
  late final TextEditingController _footerCtrl;

  // Local frontend state for Store Settings simulation
  late String _storeName;
  late String _storePhone;
  late String _storeAddress;
  late int _minDpPercent;
  late int _lateFeePerDay;
  late int _lateGracePeriodDays;
  late int _defaultDepositAmount;
  late int _minDepositAmount;

  // Local frontend state for Cashiers simulation
  late List<CashierAccountModel> _cashiersList;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appStateProvider).settings;
    _subHeaderCtrl = TextEditingController(text: settings.subHeader);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);

    _storeName = settings.storeName;
    _storePhone = settings.storePhone;
    _storeAddress = settings.storeAddress;
    _minDpPercent = settings.minDpPercent;
    _lateFeePerDay = 25000;
    _lateGracePeriodDays = settings.lateGracePeriodDays > 0 ? settings.lateGracePeriodDays : 1;
    _defaultDepositAmount = settings.defaultDepositAmount;
    _minDepositAmount = settings.minDepositAmount;

    // 1 Toko = Maksimal 1 Akun Kasir Aktif (tanpa dummy template bawaan)
    _cashiersList = settings.cashiers.isNotEmpty
        ? [settings.cashiers.first.copyWith(isActive: true)]
        : <CashierAccountModel>[];
  }

  @override
  void dispose() {
    _subHeaderCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final printer = appState.printerConfig;
    final settings = appState.settings;
    final isAdmin = appState.currentRole == AppRole.admin;

    // Pastikan _cashiersList tersinkron dengan state toko
    _cashiersList = List<CashierAccountModel>.from(settings.cashiers);

    // Guard: Hanya Owner yang berhak membuka menu Pengaturan
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_person, size: 48, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hanya Owner yang Berhak Mengatur',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Menu Pengaturan Sistem, Konfigurasi Struk, Printer, Aturan Toko, dan Akun Kasir hanya dapat diakses oleh Owner (Admin). Akun Kasir hanya memiliki hak transaksi.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.admin_panel_settings, size: 18),
                      label: const Text('Beralih ke Akun Owner (Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ref.read(appStateProvider.notifier).setRole(AppRole.admin);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.accent,
                            content: Text('Berhasil masuk sebagai Owner (Admin)'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // BAGIAN UTAMA: MANAJEMEN SHIFT KASIR (OWNER)
            // ==========================================
            _buildSectionHeader(
              title: 'Manajemen Shift Kasir',
              subtitle: 'Monitoring kasir aktif, modal awal kas, rekonsiliasi penerimaan, dan selisih kas fisik.',
              icon: Icons.history_toggle_off,
            ),
            const SizedBox(height: 10),
            _buildShiftManagementCard(),

            const SizedBox(height: 24),

            // ==========================================
            // BAGIAN 1: KELOLA AKUN KASIR
            // ==========================================
            _buildSectionHeader(
              title: 'Kelola Akun Kasir',
              subtitle: 'Manajemen akses dan kredensial login kasir toko.',
              icon: Icons.people_alt_outlined,
              action: _cashiersList.isEmpty
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Kasir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showCashierDialog(),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            _buildCashiersCard(),

            const SizedBox(height: 24),

            // ==========================================
            // BAGIAN 2: ATURAN BISNIS & TOKO
            // ==========================================
            _buildSectionHeader(
              title: 'Aturan Bisnis & Toko',
              subtitle: 'Informasi profil toko, kebijakan DP, denda, dan jaminan rental.',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 10),
            _buildStoreRulesCard(),

            const SizedBox(height: 24),

            // ==========================================
            // BAGIAN 3: PREVIEW STRUK TOKO
            // ==========================================
            _buildSectionHeader(
              title: 'Preview Struk Toko',
              subtitle: 'Tampilan informasi toko dan layout struk thermal kasir.',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 10),
            _buildReceiptPreviewCard(printer, settings),

            const SizedBox(height: 24),

            // ==========================================
            // BAGIAN 4: DESAIN LOGO & FOOTER STRUK THERMAL
            // ==========================================
            _buildSectionHeader(
              title: 'Desain Logo & Footer Struk Thermal',
              subtitle: 'Kustomisasi tampilan logo, slogan, dan footer ketentuan pada struk cetak.',
              icon: Icons.design_services_outlined,
            ),
            const SizedBox(height: 10),
            _buildReceiptDesignCard(printer, settings),

            const SizedBox(height: 24),

            // ==========================================
            // BAGIAN 5: PENGATURAN KONEKSI PRINTER THERMAL
            // ==========================================
            _buildSectionHeader(
              title: 'Pengaturan Printer Thermal Bluetooth',
              subtitle: 'Pengaturan koneksi perangkat dan lebar kertas printer thermal.',
              icon: Icons.print_outlined,
            ),
            const SizedBox(height: 10),
            _buildPrinterConnectionCard(printer),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS & SECTIONS
  // ==========================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          action,
        ],
      ],
    );
  }

  // 0. MANAJEMEN SHIFT KASIR CARD (OWNER)
  Widget _buildShiftManagementCard() {
    final appState = ref.watch(appStateProvider);
    final shifts = appState.shifts;
    final activeCount = shifts.where((s) => s.status == ShiftStatus.sedangBerjalan).length;
    final unopenCount = shifts.where((s) => s.status == ShiftStatus.belumBuka).length;
    final completedCount = shifts.where((s) => s.status == ShiftStatus.selesai).length;

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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_toggle_off, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Audit & Rekonsiliasi Shift Kasir',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pantau kasir aktif, modal awal kas fisik, ringkasan penerimaan, dan status selisih.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildQuickShiftStat('Kasir Aktif', '$activeCount', const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                _buildQuickShiftStat('Belum Buka', '$unopenCount', const Color(0xFFEA580C)),
                const SizedBox(width: 8),
                _buildQuickShiftStat('Shift Selesai', '$completedCount', const Color(0xFF2563EB)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.assessment_outlined, size: 18),
                label: const Text(
                  'Buka Menu Manajemen Shift',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShiftManagementScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShiftStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // 1. KELOLA AKUN KASIR CARD (1 Kasir per Toko)
  Widget _buildCashiersCard() {
    if (_cashiersList.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum Ada Akun Kasir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1 Toko memiliki 1 akun kasir. Daftarkan nama, email, dan kata sandi login untuk staf kasir Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Akun Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _showCashierDialog(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cashier = _cashiersList.first;
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
                // Inisial Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cashier.isActive
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.grey.shade200,
                  child: Text(
                    _getInitials(cashier.name),
                    style: TextStyle(
                      color: cashier.isActive ? AppColors.primary : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nama & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              cashier.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(cashier.isActive),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cashier.email,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Action: Edit
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: () => _showCashierDialog(cashierToEdit: cashier),
                ),
                const SizedBox(width: 8),

                // Action: Hapus
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: Colors.red.shade300),
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Hapus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _confirmDeleteCashier(cashier),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toko Anda menggunakan 1 akun kasir. Klik Edit untuk mengubah data login atau Hapus jika ingin mengganti kasir.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
        ),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade700,
        ),
      ),
    );
  }

  // 2. ATURAN BISNIS & TOKO CARD
  Widget _buildStoreRulesCard() {
    final isMobile = MediaQuery.of(context).size.width < 540;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Kebijakan & Informasi Toko',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    isMobile ? 'Edit' : 'Edit Pengaturan Toko',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showEditStoreSettingsDialog(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Sub-header 1: Informasi Toko
            const Text(
              'INFORMASI TOKO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            _buildSettingRow('Nama Toko', _storeName),
            _buildSettingRow('No. Telepon Toko', _storePhone),
            _buildSettingRow('Alamat Lengkap Toko', _storeAddress),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Sub-header 2: Aturan Penyewaan
            const Text(
              'ATURAN PENYEWAAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            _buildSettingRow('DP Minimum Sewa', '$_minDpPercent%'),
            _buildSettingRow('Denda Keterlambatan', '${CurrencyFormatter.format(_lateFeePerDay)} / hari'),
            _buildSettingRow('Toleransi Keterlambatan', '$_lateGracePeriodDays Hari'),
            _buildSettingRow('Default Deposit Uang', CurrencyFormatter.format(_defaultDepositAmount)),
            _buildSettingRow('Minimum Deposit Uang', CurrencyFormatter.format(_minDepositAmount)),
          ],
        ),
      ),
    );
  }

  // 3. PREVIEW STRUK TOKO CARD
  Widget _buildReceiptPreviewCard(PrinterConfigModel printer, StoreSettingsModel settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hasil Format Struk Thermal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Kertas 58/80 mm',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thermal Paper Mockup
            Container(
              width: 310,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                ],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Toko jika aktif
                  if (printer.showLogo) ...[
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: Image.asset(
                        printer.effectiveLogoAsset,
                        width: printer.logoDisplayWidth * 0.7,
                        height: printer.logoDisplayWidth * 0.45,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Nama Toko
                  Text(
                    _storeName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),

                  // Alamat Toko
                  Text(
                    _storeAddress,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),

                  // Telepon Toko
                  Text(
                    'Telp: $_storePhone',
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),

                  if (settings.subHeader.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      settings.subHeader,
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 8, fontStyle: FontStyle.italic, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 6),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black45)),
                  const SizedBox(height: 4),

                  // Area Transaksi Contoh
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No. Struk : RNT-20261017-A-0001', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold)),
                        Text('Tanggal   : 17 Okt 2026 14:30', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                        Text('Kasir     : Budi Santoso', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                        Text('Pelanggan : Farhan Pratama', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black45)),
                  const SizedBox(height: 4),

                  // Item rental contoh
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tenda Camping 4P x1', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                      Text('Rp 150.000', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                    ],
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sepatu Hiking (41) x1', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                      Text('Rp  70.000', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black45)),
                  const SizedBox(height: 4),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Sewa (2 Hari)', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('Rp 220.000', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DP ($_minDpPercent%)', style: const TextStyle(fontFamily: 'Courier', fontSize: 9)),
                      Text('Rp ${CurrencyFormatter.format((220000 * _minDpPercent / 100).round())}', style: const TextStyle(fontFamily: 'Courier', fontSize: 9)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deposit Jaminan', style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
                      Text('Rp ${CurrencyFormatter.format(_defaultDepositAmount)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 9)),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black45)),
                  const SizedBox(height: 4),

                  // S&K jika aktif
                  if (printer.showTerms) ...[
                    const Text('* S&K: Jaminan KTP/SIM wajib ditahan', style: TextStyle(fontFamily: 'Courier', fontSize: 7, color: Colors.black54)),
                    const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black45)),
                  ],

                  // Footer Struk
                  Text(
                    settings.receiptFooter,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 7, color: Colors.black87),
                  ),

                  // Barcode jika aktif
                  if (printer.showQrCode) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 18,
                      width: 120,
                      color: Colors.black87,
                      alignment: Alignment.center,
                      child: const Text('||||||||||||||||', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 2)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. DESAIN LOGO & FOOTER STRUK THERMAL CARD
  Widget _buildReceiptDesignCard(PrinterConfigModel printer, StoreSettingsModel settings) {
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
            // Switch Tampilkan Logo
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tampilkan Logo pada Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Cetak logo hitam-putih di bagian atas struk thermal', style: TextStyle(fontSize: 11)),
              value: printer.showLogo,
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updatePrinterConfig(
                      printer.copyWith(showLogo: val),
                    );
              },
            ),

            if (printer.showLogo) ...[
              const SizedBox(height: 10),
              const Text(
                'Pilih Gambar / Logo Struk:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              // Preset Logos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...PrinterConfigModel.presetLogos.map((preset) {
                      final isSelected = printer.selectedLogoId == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () {
                            ref.read(appStateProvider.notifier).updatePrinterConfig(
                                  printer.copyWith(selectedLogoId: preset.id),
                                );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 105,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: 52,
                                  width: 52,
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: ColorFiltered(
                                    colorFilter: const ColorFilter.matrix(<double>[
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0,      0,      0,      1, 0,
                                    ]),
                                    child: Image.asset(preset.assetPath, fit: BoxFit.contain),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  preset.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Tombol Upload Logo Kustom
                    InkWell(
                      onTap: () => _showUploadLogoDialog(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 105,
                        height: 94,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 26),
                            SizedBox(height: 6),
                            Text(
                              'Upload Logo',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Pengaturan Ukuran Logo
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  const Text('Ukuran Cetak Logo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SegmentedButton<LogoSize>(
                    segments: const [
                      ButtonSegment(value: LogoSize.kecil, label: Text('Kecil')),
                      ButtonSegment(value: LogoSize.sedang, label: Text('Sedang')),
                      ButtonSegment(value: LogoSize.besar, label: Text('Besar')),
                    ],
                    selected: {printer.logoSize},
                    onSelectionChanged: (set) {
                      ref.read(appStateProvider.notifier).updatePrinterConfig(
                            printer.copyWith(logoSize: set.first),
                          );
                    },
                  ),
                ],
              ),
            ],

            const Divider(height: 24, color: AppColors.border),

            // Slogan / Sub-header Toko
            const Text('Slogan / Keterangan Toko (Header Struk):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _subHeaderCtrl,
              decoration: const InputDecoration(
                hintText: 'Contoh: Pusat Rental Tenda & Perlengkapan Gunung',
                isDense: true,
              ),
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updateStoreSettings(
                      settings.copyWith(subHeader: val),
                    );
              },
            ),

            const Divider(height: 24, color: AppColors.border),

            // Footer Struk
            const Text('Footer Struk & Pesan Penutup:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _templateChip('Standar & Denda', () {
                    const text = 'Harap periksa kondisi alat saat pengambilan.\nKeterlambatan & kerusakan dikenakan denda sesuai ketentuan.';
                    _footerCtrl.text = text;
                    ref.read(appStateProvider.notifier).updateStoreSettings(settings.copyWith(receiptFooter: text));
                  }),
                  _templateChip('Ramah & Lestari', () {
                    const text = 'Terima kasih telah menyewa di CampRent.\nSelamat berpetualang dan tetap jaga kelestarian alam!';
                    _footerCtrl.text = text;
                    ref.read(appStateProvider.notifier).updateStoreSettings(settings.copyWith(receiptFooter: text));
                  }),
                  _templateChip('Promo Follower', () {
                    const text = 'Dapatkan voucher diskon 10% di sewa berikutnya!\nUpload petualanganmu & tag Instagram @camprent.id';
                    _footerCtrl.text = text;
                    ref.read(appStateProvider.notifier).updateStoreSettings(settings.copyWith(receiptFooter: text));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _footerCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis pesan atau catatan penutup struk...',
                isDense: true,
              ),
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updateStoreSettings(
                      settings.copyWith(receiptFooter: val),
                    );
              },
            ),

            const Divider(height: 24, color: AppColors.border),

            // Barcode & S&K
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Barcode Nomor Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Mempercepat proses scan saat barang dikembalikan', style: TextStyle(fontSize: 11)),
              value: printer.showQrCode,
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updatePrinterConfig(
                      printer.copyWith(showQrCode: val),
                    );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Ringkasan Ketentuan Sewa (S&K)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Menampilkan poin penting hak & kewajiban penyewa', style: TextStyle(fontSize: 11)),
              value: printer.showTerms,
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updatePrinterConfig(
                      printer.copyWith(showTerms: val),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 6. PENGATURAN KONEKSI PRINTER CARD
  Widget _buildPrinterConnectionCard(PrinterConfigModel printer) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.infoLight,
                child: Icon(Icons.bluetooth, color: AppColors.info),
              ),
              title: Text(
                printer.selectedPrinterName ?? 'Belum ada printer dipilih',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Alamat: ${printer.selectedPrinterAddress ?? "-"} • ${printer.isConnected ? "Terhubung" : "Terputus"}',
                style: TextStyle(
                  color: printer.isConnected ? AppColors.success : AppColors.danger,
                  fontSize: 12,
                ),
              ),
              trailing: OutlinedButton(
                child: const Text('Ganti / Scan', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Memindai perangkat Bluetooth thermal terdekat...')),
                  );
                },
              ),
            ),
            const Divider(height: 16, color: AppColors.border),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lebar Kertas Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      printer.paperWidth == PaperWidth.width58mm ? '58mm (32 karakter/baris)' : '80mm (48 karakter/baris)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                SegmentedButton<PaperWidth>(
                  segments: const [
                    ButtonSegment(value: PaperWidth.width58mm, label: Text('58 mm')),
                    ButtonSegment(value: PaperWidth.width80mm, label: Text('80 mm')),
                  ],
                  selected: {printer.paperWidth},
                  onSelectionChanged: (set) {
                    ref.read(appStateProvider.notifier).updatePrinterConfig(
                          printer.copyWith(paperWidth: set.first),
                        );
                  },
                ),
              ],
            ),
            const Divider(height: 16, color: AppColors.border),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Struk Otomatis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Langsung cetak struk setelah sewa/pengembalian disimpan', style: TextStyle(fontSize: 11)),
              value: printer.autoPrint,
              onChanged: (val) {
                ref.read(appStateProvider.notifier).updatePrinterConfig(
                      printer.copyWith(autoPrint: val),
                    );
              },
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Uji Cetak Printer Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => PrinterTestDialog.show(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateChip(String label, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFF1F5F9),
        onPressed: onSelected,
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'K';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ==========================================
  // MODAL DIALOGS
  // ==========================================

  // Dialog: Tambah / Edit Akun Kasir (1 Kasir per Toko)
  void _showCashierDialog({CashierAccountModel? cashierToEdit}) {
    final isNewAccount = cashierToEdit == null;
    final nameCtrl = TextEditingController(text: isNewAccount ? '' : cashierToEdit.name);
    final emailCtrl = TextEditingController(text: isNewAccount ? '' : cashierToEdit.email);
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    final formKey = GlobalKey<FormState>();
    bool isSavingCashier = false;
    String? cashierErrorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 460,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isNewAccount ? Icons.person_add_alt_1_outlined : Icons.person_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isNewAccount ? 'Tambah Akun Kasir' : 'Edit Akun Kasir',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isNewAccount
                                      ? 'Masukkan nama, email, dan kata sandi login kasir'
                                      : 'Perbarui nama, email, atau kata sandi login kasir',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (!isSavingCashier)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Error Banner
                      if (cashierErrorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cashierErrorMsg!,
                                  style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Nama Pengguna / Nama Kasir
                      const Text('Nama Kasir *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        enabled: !isSavingCashier,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan nama kasir (contoh: Siti Aminah)',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Nama kasir wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Email untuk Login
                      const Text('Email Login Kasir *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailCtrl,
                        enabled: !isSavingCashier,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan email kasir (contoh: kasir@camprent.com)',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                          if (!val.contains('@') || !val.contains('.')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password
                      Text(
                        isNewAccount ? 'Kata Sandi Login Kasir *' : 'Kata Sandi Baru (Opsional)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordCtrl,
                        enabled: !isSavingCashier,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: isNewAccount
                              ? 'Minimal 6 karakter'
                              : 'Kosongkan jika tidak ingin mengubah kata sandi',
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setDialogState(() => obscurePassword = !obscurePassword);
                            },
                          ),
                        ),
                        validator: (val) {
                          if (isNewAccount && (val == null || val.trim().isEmpty)) {
                            return 'Kata sandi wajib diisi untuk akun kasir baru';
                          }
                          if (val != null && val.trim().isNotEmpty && val.trim().length < 6) {
                            return 'Kata sandi minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isSavingCashier ? null : () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isSavingCashier
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setDialogState(() {
                                      isSavingCashier = true;
                                      cashierErrorMsg = null;
                                    });

                                    final appState = ref.read(appStateProvider);
                                    final currentStoreId = (appState.storeId != null && appState.storeId!.isNotEmpty)
                                        ? appState.storeId!
                                        : appState.settings.storeId;

                                    if (currentStoreId.isEmpty) {
                                      setDialogState(() {
                                        isSavingCashier = false;
                                        cashierErrorMsg = 'ID Toko tidak ditemukan. Silakan login ulang sebagai Owner.';
                                      });
                                      return;
                                    }

                                    final saveRes = await SupabaseService().createOrUpdateCashierAccount(
                                      storeId: currentStoreId,
                                      name: nameCtrl.text.trim(),
                                      email: emailCtrl.text.trim().toLowerCase(),
                                      password: passwordCtrl.text.trim(),
                                      existingCashierId: isNewAccount ? null : cashierToEdit.id,
                                    );

                                    if (!ctx.mounted) return;

                                    if (saveRes['success'] == true) {
                                      final assignedId = saveRes['id']?.toString() ??
                                          (isNewAccount ? 'cashier_${DateTime.now().millisecondsSinceEpoch}' : cashierToEdit.id);
                                      final updatedCashier = CashierAccountModel(
                                        id: assignedId,
                                        name: nameCtrl.text.trim(),
                                        email: emailCtrl.text.trim().toLowerCase(),
                                        isActive: true,
                                        createdAt: isNewAccount ? DateTime.now() : cashierToEdit.createdAt,
                                      );

                                      setState(() {
                                        _cashiersList = [updatedCashier];
                                      });

                                      final currentSettings = ref.read(appStateProvider).settings;
                                      ref.read(appStateProvider.notifier).updateStoreSettings(
                                            currentSettings.copyWith(cashiers: [updatedCashier]),
                                          );

                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.primary,
                                          duration: const Duration(seconds: 4),
                                          content: Text(
                                            'Akun kasir "${nameCtrl.text.trim()}" berhasil disimpan & siap digunakan untuk login!',
                                          ),
                                        ),
                                      );
                                    } else {
                                      setDialogState(() {
                                        isSavingCashier = false;
                                        cashierErrorMsg = saveRes['message']?.toString() ??
                                            'Gagal menyimpan akun kasir ke Supabase.';
                                      });
                                    }
                                  },
                            child: isSavingCashier
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    isNewAccount ? 'Tambah Kasir' : 'Simpan Perubahan',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Konfirmasi Hapus Akun Kasir
  void _confirmDeleteCashier(CashierAccountModel cashier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Akun Kasir?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun kasir "${cashier.name}" (${cashier.email})?\n\nSetelah dihapus, akun tidak bisa login lagi dan Anda dapat mendaftarkan kasir baru.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cashiersList = [];
              });
              ref.read(appStateProvider.notifier).removeCashier(cashier.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red.shade700,
                  content: Text('Akun kasir "${cashier.name}" berhasil dihapus.'),
                ),
              );
            },
            child: const Text('Hapus Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Dialog: Edit Pengaturan Toko & Aturan Sewa
  void _showEditStoreSettingsDialog() {
    final storeNameCtrl = TextEditingController(text: _storeName);
    final storePhoneCtrl = TextEditingController(text: _storePhone);
    final storeAddressCtrl = TextEditingController(text: _storeAddress);
    final minDpCtrl = TextEditingController(text: _minDpPercent.toString());
    final lateFeeCtrl = TextEditingController(text: _lateFeePerDay.toString());
    final gracePeriodCtrl = TextEditingController(text: _lateGracePeriodDays.toString());
    final defaultDepositCtrl = TextEditingController(text: _defaultDepositAmount.toString());
    final minDepositCtrl = TextEditingController(text: _minDepositAmount.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 580,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'EDIT PENGATURAN TOKO & ATURAN SEWA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BAGIAN 1: INFORMASI TOKO
                        const Text(
                          '1. INFORMASI TOKO',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 10),

                        // Nama Toko
                        const Text('Nama Toko *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: storeNameCtrl,
                          decoration: const InputDecoration(hintText: 'Contoh: CampRent Outdoor Gear', isDense: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nama toko wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Nomor Telepon Toko
                        const Text('Nomor Telepon Toko *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: storePhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(hintText: 'Contoh: 0812-8899-7700', isDense: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nomor telepon wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Alamat Lengkap Toko (Textarea)
                        const Text('Alamat Lengkap Toko *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: storeAddressCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Jl. Kaliurang KM 12, Sleman, DI Yogyakarta',
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Alamat toko wajib diisi';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),

                        // BAGIAN 2: ATURAN PENYEWAAN
                        const Text(
                          '2. ATURAN PENYEWAAN',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 10),

                        // DP Minimum Sewa (%)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DP Minimum Sewa (%) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: minDpCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(suffixText: '%', isDense: true),
                                    validator: (val) {
                                      final num = int.tryParse(val ?? '');
                                      if (num == null || num < 0 || num > 100) return '0 - 100%';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Toleransi Telat (Hari) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: gracePeriodCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(suffixText: 'Hari', isDense: true),
                                    validator: (val) {
                                      final num = int.tryParse(val ?? '');
                                      if (num == null || num < 0) return 'Harus angka valid';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Denda Keterlambatan per Hari (Rp)
                        const Text('Denda Keterlambatan Per Hari (Rp) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: lateFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(prefixText: 'Rp ', isDense: true),
                          validator: (val) {
                            final num = int.tryParse(val?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                            if (num == null || num < 0) return 'Nominal denda tidak valid';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Default Deposit Uang & Minimum Deposit Uang
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Default Deposit Uang *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: defaultDepositCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(prefixText: 'Rp ', isDense: true),
                                    validator: (val) {
                                      final num = int.tryParse(val?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                                      if (num == null || num < 0) return 'Nominal tidak valid';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Minimum Deposit Uang *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: minDepositCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(prefixText: 'Rp ', isDense: true),
                                    validator: (val) {
                                      final num = int.tryParse(val?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                                      if (num == null || num < 0) return 'Nominal tidak valid';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final newName = storeNameCtrl.text.trim();
                          final newPhone = storePhoneCtrl.text.trim();
                          final newAddress = storeAddressCtrl.text.trim();
                          final newMinDp = int.parse(minDpCtrl.text.trim());
                          final newLateFee = int.parse(lateFeeCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          final newGracePeriod = int.parse(gracePeriodCtrl.text.trim());
                          final newDefDeposit = int.parse(defaultDepositCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          final newMinDeposit = int.parse(minDepositCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                          setState(() {
                            _storeName = newName;
                            _storePhone = newPhone;
                            _storeAddress = newAddress;
                            _minDpPercent = newMinDp;
                            _lateFeePerDay = newLateFee;
                            _lateGracePeriodDays = newGracePeriod;
                            _defaultDepositAmount = newDefDeposit;
                            _minDepositAmount = newMinDeposit;
                          });

                          final currentSettings = ref.read(appStateProvider).settings;
                          final updatedSettings = currentSettings.copyWith(
                            storeName: newName,
                            storePhone: newPhone,
                            storeAddress: newAddress,
                            minDpPercent: newMinDp,
                            lateGracePeriodDays: newGracePeriod,
                            defaultDepositAmount: newDefDeposit,
                            minDepositAmount: newMinDeposit,
                          );

                          await ref.read(appStateProvider.notifier).updateStoreSettings(
                                updatedSettings,
                                lateFeePerDay: newLateFee,
                              );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.primary,
                                content: Text('Pengaturan toko & kebijakan rental berhasil disimpan ke Supabase.'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Dialog: Upload Logo Kustom
  void _showUploadLogoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Unggah Logo Kustom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih file gambar logo toko Anda (PNG/JPG).', style: TextStyle(fontSize: 13)),
            SizedBox(height: 10),
            Text(
              '• Format terbaik: Logo siluet hitam berlatar putih transparan.\n• Gambar akan dikompres otomatis ke ukuran maksimal 150 KB untuk printer thermal.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Pilih dari File'),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(appStateProvider.notifier).updatePrinterConfig(
                    ref.read(appStateProvider).printerConfig.copyWith(selectedLogoId: 'mountain'),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logo kustom berhasil dipilih dan dioptimalkan untuk cetak thermal!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
