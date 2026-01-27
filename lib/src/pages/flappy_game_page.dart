import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_object.dart';
import '../models/game_settings.dart';

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
  late Bird _bird;
  final List<Pipe> _pipes = [];
  bool _isGameStarted = false;
  bool _isGameOver = false;
  int _score = 0;
  Timer? _gameTimer;
  Timer? _pipeSpawnTimer;
  final Random _random = Random();
  late final Stopwatch _stopwatch;
  bool _isSubmitting = false;
  
  // Local attempt tracking
  int _currentAttempt = 0;
  int _bestScore = 0;
  final List<int> _attemptScores = [];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    // Delay reset to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetGame();
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pipeSpawnTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    final screenHeight = MediaQuery.of(context).size.height;
    setState(() {
      _bird = Bird(y: screenHeight / 2);
      _pipes.clear();
      _score = 0;
      _isGameStarted = false;
      _isGameOver = false;
    });
    _stopwatch.reset();
  }

  void _startGame() {
    if (_isGameStarted) return;

    setState(() {
      _isGameStarted = true;
      _isGameOver = false;
    });

    _stopwatch.start();

    // Game loop - runs at 60 FPS with frame limiting
    int lastFrameTime = DateTime.now().millisecondsSinceEpoch;
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isGameOver) return;
      
      // Frame limiting to prevent lag
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastFrameTime < 16) return;
      lastFrameTime = now;
      
      _updateGame();
    });

    // Spawn pipes periodically
    _pipeSpawnTimer = Timer.periodic(
      Duration(milliseconds: (widget.settings.pipeSpawnInterval * 1000).toInt()),
      (timer) {
        if (!_isGameOver) {
          _spawnPipe();
        }
      },
    );

    // Spawn initial pipe
    _spawnPipe();
  }

  void _updateGame() {
    setState(() {
      // Update bird physics
      _bird.update(widget.settings.gravity);

      // Move pipes
      for (int i = 0; i < _pipes.length; i++) {
        final pipe = _pipes[i];
        final newX = pipe.x - widget.settings.pipeSpeed * 0.005;
        _pipes[i] = pipe.copyWith(x: newX);

        // Check if bird passed pipe (using normalized coordinates)
        // Bird is at x = 0.2, pipe width is 80px normalized to ~0.05
        final pipeEndX = newX + 0.05;
        if (!pipe.passed && pipeEndX < _bird.x) {
          _pipes[i] = pipe.copyWith(passed: true);
          _score++;
        }
      }

      // Remove off-screen pipes
      _pipes.removeWhere((pipe) => pipe.x < -0.2);

      // Check collisions
      _checkCollisions();
    });
  }

  void _spawnPipe() {
    final gapY = 150.0 + _random.nextDouble() * 200.0;
    _pipes.add(Pipe(
      x: 1.2,
      gapY: gapY,
      gapHeight: 200.0,
    ));
  }

  void _checkCollisions() {
    // Get screen height from context
    final screenHeight = MediaQuery.of(context).size.height;

    // Check ground/ceiling collision
    if (_bird.y < 0 || _bird.y > screenHeight - 100) {
      _gameOver();
      return;
    }

    // Check pipe collision
    for (final pipe in _pipes) {
      final pipeX = pipe.x * MediaQuery.of(context).size.width;
      final birdScreenY = _bird.y;

      // Simple collision detection
      final birdLeft = (_bird.x - _bird.size / 2 / MediaQuery.of(context).size.width) *
          MediaQuery.of(context).size.width;
      final birdRight = (_bird.x + _bird.size / 2 / MediaQuery.of(context).size.width) *
          MediaQuery.of(context).size.width;

      if (birdRight > pipeX && birdLeft < pipeX + pipe.width) {
        // Bird is horizontally aligned with pipe
        if (birdScreenY < pipe.gapY ||
            birdScreenY + _bird.size > pipe.gapY + pipe.gapHeight) {
          _gameOver();
          return;
        }
      }
    }
  }

  void _gameOver() {
    if (_isGameOver) return;

    setState(() {
      _isGameOver = true;
    });

    _stopwatch.stop();
    _gameTimer?.cancel();
    _pipeSpawnTimer?.cancel();

    _submitScore();
  }

  void _jump() {
    if (_isGameOver) return;

    if (!_isGameStarted) {
      _startGame();
    }

    _bird.jump(widget.settings.jumpForce);
  }

  Future<void> _submitScore() async {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting score: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.lightBlue.shade100,
      body: GestureDetector(
        onTap: _jump,
        child: Stack(
          children: [
            // Game canvas
            CustomPaint(
              size: Size.infinite,
              painter: GamePainter(
                bird: _bird,
                pipes: _pipes,
                screenHeight: screenHeight,
                screenWidth: screenWidth,
              ),
            ),

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Attempts: ${_isGameStarted ? _currentAttempt + 1 : _currentAttempt}/${widget.settings.maxAttempts}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Start instruction
            if (!_isGameStarted)
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
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
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                onPressed: () {
                  if (_isGameStarted && !_isGameOver) {
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

/// Custom painter for rendering the game
class GamePainter extends CustomPainter {
  final Bird bird;
  final List<Pipe> pipes;
  final double screenHeight;
  final double screenWidth;

  GamePainter({
    required this.bird,
    required this.pipes,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw pipes
    final pipePaint = Paint()..color = Colors.green.shade700;
    for (final pipe in pipes) {
      final pipeX = pipe.x * size.width;

      // Top pipe
      canvas.drawRect(
        Rect.fromLTWH(pipeX, 0, pipe.width, pipe.gapY),
        pipePaint,
      );

      // Bottom pipe
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          pipe.gapY + pipe.gapHeight,
          pipe.width,
          size.height - (pipe.gapY + pipe.gapHeight),
        ),
        pipePaint,
      );

      // Pipe borders
      final borderPaint = Paint()
        ..color = Colors.green.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(
        Rect.fromLTWH(pipeX, 0, pipe.width, pipe.gapY),
        borderPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          pipe.gapY + pipe.gapHeight,
          pipe.width,
          size.height - (pipe.gapY + pipe.gapHeight),
        ),
        borderPaint,
      );
    }

    // Draw bird
    final birdPaint = Paint()..color = Colors.yellow.shade700;
    final birdX = bird.x * size.width;
    canvas.drawCircle(
      Offset(birdX, bird.y),
      bird.size / 2,
      birdPaint,
    );

    // Bird border
    final birdBorderPaint = Paint()
      ..color = Colors.orange.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(birdX, bird.y),
      bird.size / 2,
      birdBorderPaint,
    );

    // Draw ground
    final groundPaint = Paint()..color = Colors.brown.shade700;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 100, size.width, 100),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
