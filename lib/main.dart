import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PictureScannerApp());
}

class PictureScannerApp extends StatelessWidget {
  const PictureScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Picture Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2948C8)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2948C8),
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
