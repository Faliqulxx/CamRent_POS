import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camprent_pos/core/config/supabase_config.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/screens/main_shell.dart';
import 'package:camprent_pos/presentation/screens/login_screen.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (_) {}

  // Inisialisasi Supabase Backend
  try {
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  runApp(
    const ProviderScope(
      child: CampRentApp(),
    ),
  );
}

class CampRentApp extends ConsumerWidget {
  const CampRentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    Widget homeWidget;
    if (appState.isInitializingAuth) {
      homeWidget = const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.terrain_rounded, size: 64, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'CampRent POS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Memeriksa sesi otentikasi Supabase...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    } else if (appState.isLoggedIn) {
      homeWidget = const MainShell();
    } else {
      homeWidget = const LoginScreen();
    }

    return MaterialApp(
      title: 'CampRent POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: homeWidget,
    );
  }
}
