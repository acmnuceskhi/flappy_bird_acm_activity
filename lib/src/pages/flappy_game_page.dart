import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import '../models/game_settings.dart';
import '../models/character.dart';
import '../game/flappy_bird_game.dart';

/// Main Flappy Bird game page
class FlappyGamePage extends StatefulWidget {
  final String gameId;
  final String? code;
  final GameSettings settings;
  final String userName;
  final Character selectedCharacter;

  const FlappyGamePage({
    super.key,
    required this.gameId,
    required this.code,
    required this.settings,
    required this.userName,
    required this.selectedCharacter,
  });

  @override
  State<FlappyGamePage> createState() => _FlappyGamePageState();
}

class _FlappyGamePageState extends State<FlappyGamePage> {
  late FlappyBirdGame _game;
  late final Stopwatch _stopwatch;
  bool _isSubmitting = false;
  bool _isResetting = false; // Debounce flag for play again
  bool _isGameOver = false; // Flag to prevent duplicate game over handling
  int _score = 0;

  // Attempt tracking
  int _currentAttempt = 0;
  int _bestScore = 0;
  final List<int> _attemptScores = [];
  late String _sessionId; // Unique session ID for tracking attempts
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _focusNode = FocusNode();

    // Load existing attempts from Firebase if in competitive mode
    if (widget.code != null) {
      _loadExistingAttempts();
    }

    // Request focus after first frame so keyboard events are received
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    // Create modified settings with character-specific physics
    final characterSettings = GameSettings(
      maxAttempts: widget.settings.maxAttempts,
      gravity: widget.settings.gravity,
      pipeSpeed: widget.selectedCharacter.pipeSpeed, // Use character's speed
      pipeSpawnInterval: widget.settings.pipeSpawnInterval,
      jumpForce: widget.selectedCharacter.jumpForce, // Use character's jump
      backgroundUrl: widget.settings.backgroundUrl,
    );

    _game = FlappyBirdGame(
      settings: characterSettings,
      onGameOver: _handleGameOver,
      onScoreUpdate: () {
        if (mounted) {
          setState(() {
            _score = _game.score;
          });
        }
      },
      characterSpriteUrl: widget.selectedCharacter.spriteUrl,
    );
  }

  Future<void> _loadExistingAttempts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final attemptsSnapshot = await firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('responses')
          .doc(widget.code)
          .collection('attempts')
          .orderBy('attemptNumber')
          .get();

      if (attemptsSnapshot.docs.isNotEmpty) {
        _currentAttempt = attemptsSnapshot.docs.length;
        for (final doc in attemptsSnapshot.docs) {
          final score = doc.data()['score'] as int? ?? 0;
          _attemptScores.add(score);
        }
        if (_attemptScores.isNotEmpty) {
          _bestScore = _attemptScores.reduce(max);
        }
      }
    } catch (e) {
      debugPrint('Error loading attempts: $e');
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleGameOver(int finalScore) {
    // Prevent duplicate game over handling
    if (_isGameOver) return;
    _isGameOver = true;

    _stopwatch.stop();
    setState(() {
      _score = finalScore;
    });

    // Show dialog immediately, submit score in background
    _showGameOverDialog();
    _submitScoreInBackground();
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _isGameOver = false; // Reset game over flag for next attempt
    });
    _game.reset();
    _stopwatch.reset();
  }

  void _startGame() {
    if (!_game.isGameStarted) {
      _stopwatch.start();
    }
  }

  void _showGameOverDialog() {
    // Track attempt locally
    _currentAttempt++;
    _attemptScores.add(_score);
    _bestScore = _attemptScores.reduce(max);

    final hasMoreAttempts = _currentAttempt < widget.settings.maxAttempts;

    // Show result dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $_score',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Best Score: $_bestScore'),
            const SizedBox(height: 8),
            Text(
              'Attempts: $_currentAttempt / ${widget.settings.maxAttempts}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (hasMoreAttempts)
            TextButton(
              onPressed: _isResetting
                  ? null
                  : () {
                      if (_isResetting) return;
                      setState(() => _isResetting = true);
                      Navigator.pop(context); // Close dialog
                      _resetGame();
                      setState(() => _isResetting = false);
                    },
              child: const Text('Play Again'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: hasMoreAttempts ? const Text('Exit') : const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScoreInBackground() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final hasMoreAttempts = _currentAttempt < widget.settings.maxAttempts;

      // Save individual attempt to Firebase (only in competitive mode)
      if (widget.code != null) {
        final firestore = FirebaseFirestore.instance;

        // Save the individual attempt
        await firestore
            .collection('games')
            .doc(widget.gameId)
            .collection('responses')
            .doc(widget.code)
            .collection('attempts')
            .doc('attempt_${_currentAttempt}')
            .set({
              'attemptNumber': _currentAttempt,
              'score': _score,
              'timeTakenSeconds': _stopwatch.elapsed.inSeconds,
              'completedAt': FieldValue.serverTimestamp(),
              'characterName': widget.selectedCharacter.name,
              'sessionId': _sessionId,
            });

        // If all attempts are done, calculate and save final score
        if (!hasMoreAttempts) {
          await firestore
              .collection('games')
              .doc(widget.gameId)
              .collection('responses')
              .doc(widget.code)
              .update({
                'score': _bestScore,
                'timeTakenSeconds': _stopwatch.elapsed.inSeconds,
                'lastPlayedAt': FieldValue.serverTimestamp(),
                'totalAttempts': _currentAttempt,
              });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting score: $e')));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade100,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space) {
            _game.handleTap();
            _startGame();
          }
        },
        child: GestureDetector(
          onTap: () {
            _game.handleTap();
            _startGame();
          },
          child: Stack(
            children: [
              // Background image if URL provided
              if (widget.settings.backgroundUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    widget.settings.backgroundUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.lightBlue.shade100);
                    },
                  ),
                ),

              // Flame game widget
              GameWidget(game: _game),

              // Score display
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '$_score',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Attempts indicator
              Positioned(
                top: 50,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Attempts: ${_game.isGameStarted ? _currentAttempt + 1 : _currentAttempt + 1}/${widget.settings.maxAttempts}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Start instruction (only show before first tap)
              if (_currentAttempt == 0 && !_game.isGameStarted)
                const Center(
                  child: Text(
                    'Tap to Start',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),

              // User name display
              Positioned(
                top: 50,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 100,
                left: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    if (_game.isGameStarted && !_game.isGameOver) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Exit Game?'),
                          content: const Text(
                            'Your current game will not be saved.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: const Text('Exit'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
