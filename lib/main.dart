import 'package:flutter/material.dart';
import 'splash_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Thermometer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashPage(), // 최초 시작은 SplashPage
    );
  }
}
