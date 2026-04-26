import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/WelcomeScreen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAvMajBi4k8xnckT0IoTkiZac0YCWfNn_k",
      appId: "1:1043940728580:web:b57764c4a71726cfe5fa51",
      messagingSenderId: "1043940728580",
      projectId: "zad-def41",
      storageBucket: "zad-def41.firebasestorage.app",
    ),
  );

  runApp(const ZADApp());
}

class ZADApp extends StatelessWidget {
  const ZADApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ZAD",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
