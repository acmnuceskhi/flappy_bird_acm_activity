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
    final skyBlue = const Color(0xFF87CEEB);
    final pipeGreen = const Color(0xFF2E7D32);
    final birdYellow = const Color(0xFFFFD54F);

    return MaterialApp(
      title: 'Flappy Bird Booth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(primary: Colors.blue),
        useMaterial3: true,
        //THEME DATA
        // primaryColor: birdYellow,
        // scaffoldBackgroundColor: skyBlue,
        // colorScheme: ColorScheme.light(
        //   primary: birdYellow,
        //   secondary: pipeGreen,
        //   background: skyBlue,
        // ),
        // appBarTheme: AppBarTheme(
        //   backgroundColor: Colors.transparent,
        //   elevation: 0,
        //   centerTitle: true,
        //   titleTextStyle: const TextStyle(
        //     fontSize: 20,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.white,
        //   ),
        //   iconTheme: const IconThemeData(color: Colors.white),
        // ),
        // elevatedButtonTheme: ElevatedButtonThemeData(
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: birdYellow,
        //     foregroundColor: Colors.black,
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(12),
        //     ),
        //     padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        //   ),
        // ),
        // cardTheme: CardThemeData(
        //   color: Colors.white.withOpacity(0.9),
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(14),
        //   ),
        //   elevation: 6,
        // ),
        // textTheme: ThemeData.light().textTheme.apply(
        //   bodyColor: Colors.white,
        //   displayColor: Colors.black,
        // ),
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
