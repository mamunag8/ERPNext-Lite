import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErpApiClient.instance.init();
  runApp(const NexErpMobileApp());
}

class NexErpMobileApp extends StatelessWidget {
  const NexErpMobileApp({super.key});

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B6E4F),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F1412)
          : const Color(0xFFF6F8F7),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF0F1412) : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF18201D) : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141B18) : Colors.white,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ErpApiClient.instance,
      builder: (BuildContext context, _) {
        final bool isLoggedIn = ErpApiClient.instance.isLoggedIn;
        return MaterialApp(
          title: 'ERPNext Lite',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
