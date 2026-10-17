import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email dan kata sandi wajib diisi.';
      });
      return;
    }

    final success = await ref.read(appStateProvider.notifier).login(
          email: email,
          password: password,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (!success) {
        setState(() {
          _errorMessage = 'Email atau kata sandi tidak valid. Pastikan akun terdaftar di Supabase atau gunakan demo.';
        });
      }
    }
  }

  void _showRegisterStoreDialog() {
    final nameCtrl = TextEditingController();
    final storeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isRegLoading = false;
    String? regError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daftar Toko Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Akun Pemilik (Owner Multi-Tenant)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (regError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(regError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Nama Toko Rental', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: storeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Merbabu Outdoor Rent',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Nama Lengkap Pemilik (Owner)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Ahmad Rizky',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Email Login', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'owner@tokoanda.com',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Kata Sandi (Minimal 6 Karakter)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Minimal 6 karakter',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Nomor WhatsApp Toko', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '08123456789',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isRegLoading
                  ? null
                  : () async {
                      if (storeCtrl.text.trim().isEmpty ||
                          nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          passCtrl.text.trim().length < 6) {
                        setDialogState(() {
                          regError = 'Semua field wajib diisi dan password minimal 6 karakter.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isRegLoading = true;
                        regError = null;
                      });

                      final success = await ref.read(appStateProvider.notifier).registerStore(
                            email: emailCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            ownerName: nameCtrl.text.trim(),
                            storeName: storeCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          );

                      if (ctx.mounted) {
                        if (success) {
                          Navigator.pop(ctx);
                        } else {
                          setDialogState(() {
                            isRegLoading = false;
                            regError = 'Gagal mendaftarkan toko. Periksa koneksi internet atau gunakan email lain.';
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isRegLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Daftar & Masuk'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 540;

    final formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                        // App Brand & Logo
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/images/camprent_logo.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: AppColors.primary,
                                    child: const Icon(
                                      Icons.terrain,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'CampRent POS',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sistem Kasir & Rental Perlengkapan Outdoor',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Supabase Cloud Connected Badge
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cloud_done, size: 14, color: Color(0xFF059669)),
                                        SizedBox(width: 5),
                                        Text(
                                          'Supabase Cloud Aktif',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.offline_bolt_outlined, size: 14, color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Multi-Tenant SaaS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner if any
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        const Text(
                          'Email Akun Toko',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'owner@camprent.com atau kasir@camprent.com',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            prefixIcon: const Icon(Icons.alternate_email, size: 20, color: AppColors.textSecondary),
                            filled: true,
                            fillColor: const Color(0xFFF9FAF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        const Text(
                          'Kata Sandi (PIN / Password)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9FAF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Quick demo buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _emailController.text = 'owner@camprent.com';
                                  _passwordController.text = 'admin123';
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Isi Demo Owner', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _emailController.text = 'kasir@camprent.com';
                                  _passwordController.text = 'kasir123';
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Isi Demo Kasir', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Remember Me Checkbox
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Simpan sesi login offline di perangkat ini',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Masuk ke Sistem POS',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),

                        // Register New Store Button
                        OutlinedButton.icon(
                          onPressed: _showRegisterStoreDialog,
                          icon: const Icon(Icons.add_business, size: 16),
                          label: const Text(
                            'Daftar Toko Baru (Pemilik / Owner)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // System info footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_sync, size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Supabase PostgreSQL • RLS Store Isolation • SQLite Cache',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

    return Scaffold(
      backgroundColor: isMobile ? Colors.white : const Color(0xFFF1F5F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 24,
              vertical: isMobile ? 16 : 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: isMobile
                  ? formContent
                  : Card(
                      elevation: 4,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.border, width: 1),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: formContent,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
