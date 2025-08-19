import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/loginpage.dart';
import 'screens/createroute.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TranZipAround',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF1A0023),
        primaryColor: const Color(0xFFc349cc),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFc349cc)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: {'/createRoute': (context) => const CreateRoutePage()},
    );
  }
}
