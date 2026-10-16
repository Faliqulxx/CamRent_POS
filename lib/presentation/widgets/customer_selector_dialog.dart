import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/data/models/customer_model.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';
import 'package:camprent_pos/presentation/widgets/status_pill.dart';

class CustomerSelectorDialog extends StatefulWidget {
  const CustomerSelectorDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CustomerSelectorDialog(),
    );
  }

  @override
  State<CustomerSelectorDialog> createState() => _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends State<CustomerSelectorDialog> {
  String _searchQuery = '';
  bool _isCreatingNew = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final appState = ref.watch(appStateProvider);
        final filteredCustomers = appState.customers.where((c) {
          final query = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(query) || c.phone.contains(query);
        }).toList();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 580),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isCreatingNew ? 'Tambah Pelanggan Baru' : 'Pilih Pelanggan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!_isCreatingNew) ...[
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau no. WhatsApp...',
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
                  const SizedBox(height: 12),

                  // Button Tambah Baru
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Tambah Pelanggan Baru'),
                    onPressed: () => setState(() => _isCreatingNew = true),
                  ),
                  const SizedBox(height: 12),

                  // List of Customers
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? const Center(
                            child: Text(
                              'Pelanggan tidak ditemukan',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (_, __) => const Divider(height: 10),
                            itemBuilder: (ctx, idx) {
                              final customer = filteredCustomers[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: CircleAvatar(
                                  backgroundColor: customer.isBlacklisted ? AppColors.danger : AppColors.primary,
                                  child: Text(
                                    customer.name[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    if (customer.isBlacklisted)
                                      StatusPill.blacklist(),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('WA: ${customer.phone} • ${customer.totalRentals}x sewa', style: const TextStyle(fontSize: 12)),
                                    if (customer.isBlacklisted && customer.blacklistReason != null)
                                      Text(
                                        'Catatan: ${customer.blacklistReason}',
                                        style: const TextStyle(color: AppColors.danger, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: customer.isBlacklisted ? AppColors.danger : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Pilih', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    ref.read(appStateProvider.notifier).selectCustomer(customer);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ] else ...[
                  // FORM TAMBAH PELANGGAN BARU
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap *',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Nomor WhatsApp *',
                              hintText: 'Contoh: 081234567890',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Alamat (Opsional)',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Catatan Pelanggan (Opsional)',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  child: const Text('Kembali'),
                                  onPressed: () => setState(() => _isCreatingNew = false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  child: const Text('Simpan & Pilih'),
                                  onPressed: () {
                                    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Nama dan nomor WA wajib diisi')),
                                      );
                                      return;
                                    }

                                    final normalizedPhone = CustomerModel.normalizePhone(_phoneCtrl.text.trim());
                                    final newCust = CustomerModel(
                                      id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
                                      name: _nameCtrl.text.trim(),
                                      phone: normalizedPhone,
                                      address: _addressCtrl.text.trim(),
                                      note: _noteCtrl.text.trim(),
                                      totalRentals: 0,
                                      isBlacklisted: false,
                                    );

                                    ref.read(appStateProvider.notifier).addCustomer(newCust);
                                    ref.read(appStateProvider.notifier).selectCustomer(newCust);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
