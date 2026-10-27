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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ErpApiClient.instance,
      builder: (BuildContext context, _) {
        final bool isLoggedIn = ErpApiClient.instance.isLoggedIn;
        return MaterialApp(
          title: 'ERPNext Lite',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0B6E4F),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0B6E4F),
              brightness: Brightness.dark,
            ),
          ),
          home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
