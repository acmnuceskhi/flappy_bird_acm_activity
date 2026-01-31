import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'src/pages/auth_gate.dart';
import 'src/pages/user_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundBlack = Colors.black;
    final darkSurface = const Color(0xFF121212);
    final redAccentColor = const Color(0xFFFF6B6B);

    return MaterialApp(
      title: 'Flappy Bird Booth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: redAccentColor,
        scaffoldBackgroundColor: backgroundBlack,
        colorScheme: ColorScheme.dark(
          primary: redAccentColor,
          secondary: Colors.red.shade700,
          surface: darkSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: redAccentColor,
          ),
          iconTheme: IconThemeData(color: redAccentColor),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: redAccentColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        cardTheme: CardThemeData(
          color: darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.grey[300],
          displayColor: Colors.grey[300],
        ),
      ),
      home: const AppRoot(),
    );
  }
}

/// Root widget that checks authentication state
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          return const UserHome();
        }

        // User is not logged in
        return const AuthGate();
      },
    );
  }
}
