import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/presentation/screens/main_shell.dart';
import 'package:camprent_pos/presentation/screens/login_screen.dart';
import 'package:camprent_pos/presentation/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (_) {}
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

    return MaterialApp(
      title: 'CampRent POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: appState.isLoggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
