import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/screens/pos_screen.dart';
import 'package:camprent_pos/presentation/screens/rentals_screen.dart';
import 'package:camprent_pos/presentation/screens/inventory_screen.dart';
import 'package:camprent_pos/presentation/screens/customers_screen.dart';
import 'package:camprent_pos/presentation/screens/reports_screen.dart';
import 'package:camprent_pos/presentation/screens/settings_screen.dart';
import 'package:camprent_pos/presentation/screens/shift_management_screen.dart';
import 'package:camprent_pos/presentation/widgets/login_role_dialog.dart';
import 'package:camprent_pos/presentation/widgets/open_shift_view.dart';
import 'package:camprent_pos/presentation/widgets/shift_guard_dialog.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isOnline = appState.networkStatus == NetworkStatus.online;
    final isAdmin = appState.currentRole == AppRole.admin;
    final isKasirShiftActive = isAdmin || appState.activeCashierShift != null;

    // Badges
    final cartItemCount = appState.newRentalForm.cartItems.fold(0, (sum, ci) => sum + ci.qty);
    final overdueCount = appState.rentals.where((r) => r.isOverdue).length;

    // PRD: Owner has full access (Kasir, Transaksi, Stok CRUD, Pelanggan, Laporan, Pengaturan)
    // Kasir only has operational access (Kasir, Transaksi, Stok read-only, Pelanggan).
    // Kasir TIDAK BISA mengakses Pengaturan dan Laporan!
    // Kasir WAJIB membuka shift sebelum mengakses transaksi.
    final List<Widget> screens = isAdmin
        ? const [
            PosScreen(),
            RentalsScreen(),
            InventoryScreen(),
            CustomersScreen(),
            ReportsScreen(),
            SettingsScreen(),
          ]
        : [
            isKasirShiftActive ? const PosScreen() : const OpenShiftView(),
            const RentalsScreen(),
            const InventoryScreen(),
            const CustomersScreen(),
          ];

    final List<String> titles = isAdmin
        ? const [
            'Kasir Rental (POS)',
            'Transaksi & Pengembalian',
            'Inventori Stok Alat',
            'Data Pelanggan',
            'Laporan & Keuangan (Owner)',
            'Pengaturan Sistem (Owner)',
          ]
        : [
            isKasirShiftActive ? 'Kasir Rental (POS)' : 'Buka Shift Kasir',
            'Transaksi & Pengembalian',
            'Inventori Stok Alat',
            'Data Pelanggan',
          ];

    // Safely clamp index if switching from Owner (index 4 or 5) to Kasir (max 3)
    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Badge(
          isLabelVisible: cartItemCount > 0,
          label: Text('$cartItemCount'),
          child: const Icon(Icons.storefront_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: cartItemCount > 0,
          label: Text('$cartItemCount'),
          child: const Icon(Icons.storefront, color: AppColors.primary),
        ),
        label: 'Kasir',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: overdueCount > 0,
          backgroundColor: AppColors.danger,
          label: Text('$overdueCount'),
          child: const Icon(Icons.receipt_long_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: overdueCount > 0,
          backgroundColor: AppColors.danger,
          label: Text('$overdueCount'),
          child: const Icon(Icons.receipt_long, color: AppColors.primary),
        ),
        label: 'Transaksi',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
        label: 'Stok',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people, color: AppColors.primary),
        label: 'Pelanggan',
      ),
      if (isAdmin) ...[
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics, color: AppColors.primary),
          label: 'Laporan',
        ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: AppColors.primary),
          label: 'Pengaturan',
        ),
      ],
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 520;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 12 : 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/camprent_logo.jpg',
                width: isMobile ? 28 : 32,
                height: isMobile ? 28 : 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMobile ? 'CampRent' : 'CampRent POS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 16),
                ),
                if (!isMobile)
                  Text(
                    titles[safeIndex],
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          // Network Status Simulator Chip (PRD 5.8)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: isOnline ? 'Status: Online (Sinkron otomatis)' : 'Status: Offline (Disimpan lokal)',
              child: InkWell(
                onTap: () {
                  ref.read(appStateProvider.notifier).toggleNetwork();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      backgroundColor: isOnline ? Colors.orange.shade800 : AppColors.success,
                      content: Text(
                        isOnline
                            ? 'Mode Offline disimulasikan: Transaksi disimpan di lokal database SQLite.'
                            : 'Mode Online aktif: 2 transaksi outbox tersinkron otomatis ke Supabase.',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 4 : 4),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade900.withOpacity(0.4) : Colors.orange.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 13,
                        color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? 'Online' : 'Offline (${appState.outboxCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Owner Shift Management Menu Action (PRD Section 2 & 3)
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Dashboard Manajemen Shift Kasir',
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ShiftManagementScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_toggle_off, size: 14, color: Colors.white),
                        if (!isMobile) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Shift Kasir',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // User Role Profile Button (PRD 2: Owner vs Kasir Switcher Dialog)
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 12),
            child: InkWell(
              onTap: () => LoginRoleDialog.show(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAdmin ? AppColors.accent : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAdmin ? Colors.amber.shade300 : Colors.white30,
                    width: 1,
                  ),
                  boxShadow: isAdmin
                      ? const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.store,
                      size: isMobile ? 13 : 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAdmin ? 'Owner' : 'Kasir',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: isMobile ? 14 : 16, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isMobile ? 64 : 70,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSel = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? AppColors.primary : AppColors.textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSel = states.contains(WidgetState.selected);
            return IconThemeData(
              size: isMobile ? 20 : 24,
              color: isSel ? AppColors.primary : AppColors.textSecondary,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (idx) {
            // Jika kasir mencoba mengakses transaksi saat shift belum aktif
            if (!isAdmin && !isKasirShiftActive && idx == 1) {
              ShiftGuardDialog.show(
                context,
                onOpenShift: () {
                  setState(() => _currentIndex = 0);
                },
              );
              return;
            }
            setState(() => _currentIndex = idx);
          },
          indicatorColor: AppColors.primary.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }
}
