import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'code_entry_page.dart';

/// Home page shown after admin login - displays code entry
class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flappy Bird Booth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: const CodeEntryPage(),
    );
  }
}
