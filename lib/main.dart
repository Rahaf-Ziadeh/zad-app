import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/WelcomeScreen.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    );
  }
}
