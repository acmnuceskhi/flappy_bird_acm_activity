import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_settings.dart';
import 'code_entry_page.dart';
import 'character_selection_page.dart';

/// Game mode selection page - user chooses between casual and competitive
class GameModeSelectionPage extends StatelessWidget {
  const GameModeSelectionPage({super.key});

  Future<void> _launchCasualMode(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Query for game named "Flappy Bird"
      final gameQuery = await firestore
          .collection('games')
          .where('name', isEqualTo: 'Flappy Bird')
          .limit(1)
          .get();

      if (gameQuery.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flappy Bird game not found')),
        );
        return;
      }

      final gameId = gameQuery.docs.first.id;

      // Load game settings
      final settingsDoc = await firestore
          .collection('games')
          .doc(gameId)
          .collection('settings')
          .doc('flappybird')
          .get();

      final settings = GameSettings.fromFirestore(settingsDoc.data());

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CharacterSelectionPage(
            gameId: gameId,
            code: null,
            settings: settings,
            userName: 'Casual Player',
          ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.red.shade900],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Flappy Bird',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent.shade200,
                    shadows: const [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black54,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select Game Mode',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey[300]),
                ),
                const SizedBox(height: 32),

                // Casual Mode Card (dark)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.grey[850],
                  elevation: 8,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _launchCasualMode(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[850],
                        border: Border.all(
                          color: Colors.red.shade800.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.shade200.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flight,
                              size: 36,
                              color: Colors.redAccent.shade200,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Casual Mode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.grey[100],
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Play for fun — no code required',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _launchCasualMode(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Play'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Competitive Mode Card (dark)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.grey[850],
                  elevation: 8,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CodeEntryPage(isCompetitiveMode: true),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[850],
                        border: Border.all(
                          color: Colors.red.shade800.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.shade200.withOpacity(
                                0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              size: 36,
                              color: Colors.redAccent.shade200,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Competitive Mode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.grey[100],
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Enter your code to compete for the leaderboard',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CodeEntryPage(
                                    isCompetitiveMode: true,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Enter Code'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
