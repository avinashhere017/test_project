import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ProductScannerApp());
}

class ProductScannerApp extends StatelessWidget {
  const ProductScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accentTeal = Color(0xFF2DD4BF);
    const accentIndigo = Color(0xFF6366F1);
    const background = Color(0xFF0A0A1A);

    return MaterialApp(
      title: 'Product Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentIndigo,
          brightness: Brightness.dark,
          primary: accentIndigo,
          secondary: accentTeal,
          surface: const Color(0xFF14132B),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
