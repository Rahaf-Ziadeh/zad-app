import 'package:flutter/material.dart';
import 'screens/WelcomeScreen.dart';

void main() {
  runApp(const ZADApp());
}

class ZADApp extends StatelessWidget {
  const ZADApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}
