import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/status_pill.dart';
import 'package:camprent_pos/presentation/widgets/customer_selector_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final customers = appState.customers;
    final isAdmin = appState.currentRole == AppRole.admin;

    final filtered = customers.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau WhatsApp pelanggan...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                  onPressed: () => CustomerSelectorDialog.show(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = filtered[idx];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: c.isBlacklisted ? AppColors.danger : AppColors.primary,
                              child: Text(
                                c.name[0],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (c.isBlacklisted)
                                        StatusPill.blacklist(),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'No. WhatsApp: ${c.phone}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${c.totalRentals}x Sewa',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        if (c.address.isNotEmpty || c.note.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (c.address.isNotEmpty)
                            Text('Alamat: ${c.address}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (c.note.isNotEmpty)
                            Text('Catatan: ${c.note}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        if (c.isBlacklisted && c.blacklistReason != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.block, color: AppColors.danger, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Alasan Blacklist: ${c.blacklistReason}',
                                    style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isAdmin) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  c.isBlacklisted ? Icons.check_circle_outline : Icons.block,
                                  size: 16,
                                  color: c.isBlacklisted ? AppColors.success : AppColors.danger,
                                ),
                                label: Text(
                                  c.isBlacklisted ? 'Cabut Blacklist' : 'Tandai Blacklist',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.isBlacklisted ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                                onPressed: () {
                                  ref.read(appStateProvider.notifier).toggleCustomerBlacklist(
                                        c.id,
                                        reason: 'Diblacklist oleh owner via panel admin',
                                      );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
