import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import '../models/game_settings.dart';
import '../game/flappy_bird_game.dart';

/// Main Flappy Bird game page
class FlappyGamePage extends StatefulWidget {
  final String gameId;
  final String code;
  final GameSettings settings;
  final String userName;

  const FlappyGamePage({
    super.key,
    required this.gameId,
    required this.code,
    required this.settings,
    required this.userName,
  });

  @override
  State<FlappyGamePage> createState() => _FlappyGamePageState();
}

class _FlappyGamePageState extends State<FlappyGamePage> {
  late FlappyBirdGame _game;
  late final Stopwatch _stopwatch;
  bool _isSubmitting = false;
  int _score = 0;

  // Local attempt tracking
  int _currentAttempt = 0;
  int _bestScore = 0;
  final List<int> _attemptScores = [];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _game = FlappyBirdGame(
      settings: widget.settings,
      onGameOver: _handleGameOver,
      onScoreUpdate: () {
        if (mounted) {
          setState(() {
            _score = _game.score;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleGameOver(int finalScore) {
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
              onPressed: () {
                Navigator.pop(context);
                _resetGame();
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
      // Track attempt locally
      _currentAttempt++;
      _attemptScores.add(_score);
      _bestScore = _attemptScores.reduce(max);

      final hasMoreAttempts = _currentAttempt < widget.settings.maxAttempts;

      // Only submit to Firestore after all attempts are used
      if (!hasMoreAttempts) {
        final firestore = FirebaseFirestore.instance;
        final responseRef = firestore
            .collection('games')
            .doc(widget.gameId)
            .collection('responses')
            .doc(widget.code);

        await responseRef.update({
          'score': _bestScore,
          'timeTakenSeconds': _stopwatch.elapsed.inSeconds,
          'lastPlayedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Show result dialog
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                onPressed: () {
                  Navigator.pop(context);
                  _resetGame();
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
      body: GestureDetector(
        onTap: () {
          _game.handleTap();
          _startGame();
        },
        child: Stack(
          children: [
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
                  'Attempts: ${_game.isGameStarted ? _currentAttempt : _currentAttempt}/${widget.settings.maxAttempts}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Start instruction
            if (!_game.isGameStarted)
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
    );
  }
}
