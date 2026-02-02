import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/character.dart';
import '../models/game_settings.dart';
import '../providers/character_provider.dart';
import 'flappy_game_page.dart';

/// Character selection screen shown before each attempt
class CharacterSelectionPage extends StatefulWidget {
  final String gameId;
  final String? code;
  final GameSettings settings;
  final String userName;

  const CharacterSelectionPage({
    super.key,
    required this.gameId,
    required this.code,
    required this.settings,
    required this.userName,
  });

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load characters using provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      provider.loadCharacters(widget.gameId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCharacter(BuildContext context, Character character) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FlappyGamePage(
          gameId: widget.gameId,
          code: widget.code,
          settings: widget.settings,
          userName: widget.userName,
          selectedCharacter: character,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Select Your Character',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.redAccent.shade200,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.red.shade900],
          ),
        ),
        child: Consumer<CharacterProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error,
                      color: Colors.redAccent.shade200,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${provider.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade200,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final characters = provider.characters;
            final filteredCharacters = characters
                .where(
                  (character) => character.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
                )
                .toList();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Search Box (dark themed)
                  TextField(
                    controller: _searchController,
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search characters...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.redAccent.shade200,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[400]),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[100]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🎮 Choose Your Character',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[100],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick a bird and try to beat your best!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Show "No results" message if filtered list is empty
                  if (filteredCharacters.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No characters found',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Use horizontal scroll for 3 or fewer characters
                          if (filteredCharacters.length <= 3) {
                            return Center(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: filteredCharacters.map((character) {
                                    return Container(
                                      width: 200,
                                      height: 340,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: _CharacterCard(
                                        character: character,
                                        onSelect: () => _selectCharacter(
                                          context,
                                          character,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          }
                          // Use grid for 4+ characters
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 0.85,
                                ),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: filteredCharacters.length,
                            itemBuilder: (context, index) {
                              final character = filteredCharacters[index];
                              return _CharacterCard(
                                character: character,
                                onSelect: () =>
                                    _selectCharacter(context, character),
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

  const _CharacterCard({required this.character, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // Normalize stats for progress bars (0-10 range)
    final speedPercent = (character.pipeSpeed / 10.0).clamp(0.0, 1.0);
    final jumpPercent = (character.jumpForce / 15.0).clamp(0.0, 1.0);

    return Card(
      color: Colors.grey[850],
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade800.withOpacity(0.6), width: 1),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.redAccent.withOpacity(0.12),
        highlightColor: Colors.redAccent.withOpacity(0.06),
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
                            color: Colors.redAccent.shade200,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flutter_dash,
                            size: 45,
                            color: Colors.black,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: character.spriteUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                width: 70,
                                height: 70,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.redAccent.shade200,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 35,
                                    color: Colors.grey[400],
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
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  character.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[100],
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
                      Icon(
                        Icons.speed,
                        size: 16,
                        color: Colors.redAccent.shade200,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Speed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[300],
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
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.redAccent.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Jump stat
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Jump',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[300],
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
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.red.shade300,
                      ),
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
