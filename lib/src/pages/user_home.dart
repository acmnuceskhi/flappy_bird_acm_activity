import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_mode_selection_page.dart';
import 'admin_password_gate.dart';
import '../models/game_settings.dart';

/// Home page shown after admin login - displays code entry
class UserHome extends StatelessWidget {
  const UserHome({super.key});

  Future<void> _openAdminPanel(BuildContext context) async {
    try {
      // Load game settings to pass to admin panel
      final firestore = FirebaseFirestore.instance;
      final gamesSnapshot = await firestore
          .collection('games')
          .where('name', isEqualTo: 'Flappy Bird')
          .limit(1)
          .get();

      if (gamesSnapshot.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game not found in database')),
        );
        return;
      }

      final gameId = gamesSnapshot.docs.first.id;

      // Load settings
      final settingsDoc = await firestore
          .collection('games')
          .doc(gameId)
          .collection('settings')
          .doc('flappybird')
          .get();

      final settings = GameSettings.fromFirestore(settingsDoc.data());

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              AdminPasswordGate(gameId: gameId, settings: settings),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Flappy Bird Booth',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.redAccent.shade200,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openAdminPanel(context),
            tooltip: 'Admin Panel',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.red.shade900],
          ),
        ),
        child: const GameModeSelectionPage(),
      ),
    );
  }
}
