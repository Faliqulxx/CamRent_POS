import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Login dengan Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Pendaftaran Toko Baru (Owner)
  Future<AuthResponse> registerStoreOwner({
    required String email,
    required String password,
    required String ownerName,
    required String storeName,
    String? phone,
    String? address,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': ownerName,
        'store_name': storeName,
      },
    );

    final user = response.user;
    if (user != null) {
      // 1. Buat data store baru
      final storeInsert = await _supabase
          .from('stores')
          .insert({
            'name': storeName,
            'address': address ?? '',
            'phone': phone ?? '',
          })
          .select()
          .single();

      final storeId = storeInsert['id'];

      // 2. Buat profil user sebagai Owner
      await _supabase.from('profiles').insert({
        'id': user.id,
        'store_id': storeId,
        'role': 'owner',
        'name': ownerName,
        'email': email.trim(),
      });
    }

    return response;
  }

  /// Mendapatkan Profil Akun & Data Toko Saat Ini
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('*, stores(*)')
          .eq('id', user.id)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Keluar / Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
