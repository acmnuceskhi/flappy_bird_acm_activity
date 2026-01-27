import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/character.dart';
import '../models/game_settings.dart';
import 'flappy_game_page.dart';

/// Character selection screen shown before each attempt
class CharacterSelectionPage extends StatelessWidget {
  final String gameId;
  final String code;
  final GameSettings settings;
  final String userName;

  const CharacterSelectionPage({
    super.key,
    required this.gameId,
    required this.code,
    required this.settings,
    required this.userName,
  });

  Future<List<Character>> _loadCharacters() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('characters')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty) {
        return [Character.defaultBird];
      }

      return snapshot.docs
          .map((doc) => Character.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading characters: $e');
      return [Character.defaultBird];
    }
  }

  void _selectCharacter(BuildContext context, Character character) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FlappyGamePage(
          gameId: gameId,
          code: code,
          settings: settings,
          userName: userName,
          selectedCharacter: character,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Character'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: FutureBuilder<List<Character>>(
        future: _loadCharacters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final characters = snapshot.data ?? [Character.defaultBird];

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '🎮 Choose Your Character',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll play 3 attempts with this character',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Use horizontal scroll for 3 or fewer characters
                      if (characters.length <= 3) {
                        return Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: characters.map((character) {
                                return Container(
                                  width: 200,
                                  height: 340,
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                  child: _CharacterCard(
                                    character: character,
                                    onSelect: () => _selectCharacter(context, character),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      }
                      // Use grid for 4+ characters
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.85,
                        ),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: characters.length,
                        itemBuilder: (context, index) {
                          final character = characters[index];
                          return _CharacterCard(
                            character: character,
                            onSelect: () => _selectCharacter(context, character),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Individual character card with stats
class _CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onSelect;

  const _CharacterCard({
    required this.character,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Normalize stats for progress bars (0-10 range)
    final speedPercent = (character.pipeSpeed / 10.0).clamp(0.0, 1.0);
    final jumpPercent = (character.jumpForce / 15.0).clamp(0.0, 1.0);

    return Card(
      elevation: 8,
      shadowColor: Colors.blue.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 2),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.blue.withOpacity(0.3),
        highlightColor: Colors.blue.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Character sprite preview
              Container(
                height: 90,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                child: Center(
                  child: character.spriteUrl.isEmpty
                      ? Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flutter_dash,
                            size: 45,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              character.spriteUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 35,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ),

              // Character name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  character.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Stats with progress bars
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Speed stat
                    Row(
                      children: [
                        Icon(Icons.speed, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Speed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: speedPercent,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Jump stat
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Jump',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: jumpPercent,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
