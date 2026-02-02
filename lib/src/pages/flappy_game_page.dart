import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:just_audio/just_audio.dart';
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
  bool _isLoading = true; // Track loading state
  int _score = 0;

  // Attempt tracking (local session only)
  int _currentAttempt = 0;
  int _bestScore = 0;
  final List<int> _attemptScores = [];
  late FocusNode _focusNode;
  late AudioPlayer _audioPlayer;
  late AudioPlayer _backgroundMusicPlayer;
  late AudioPlayer _pipePassedSoundPlayer;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _focusNode = FocusNode();
    _audioPlayer = AudioPlayer();
    _backgroundMusicPlayer = AudioPlayer();
    _pipePassedSoundPlayer = AudioPlayer();

    // Pre-load the game over sound to eliminate delay on first play
    _preLoadGameOverSound();

    // Load and play background music if available
    _loadBackgroundMusic();

    // Load pipe passed sound if available
    _loadPipePassedSound();

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
      backgroundMusicUrl: widget.settings.backgroundMusicUrl,
      pipePassedSoundUrl: widget.settings.pipePassedSoundUrl,
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
      onPipePassed: _playPipePassedSound,
      characterSpriteUrl: widget.selectedCharacter.spriteUrl,
    );

    // Wait for game to fully load before hiding loading overlay
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Wait for game assets to load
    while (!_game.isAssetsLoaded && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _audioPlayer.dispose();
    _backgroundMusicPlayer.dispose();
    _pipePassedSoundPlayer.dispose();
    super.dispose();
  }

  void _handleGameOver(int finalScore) {
    // Prevent duplicate game over handling
    if (_isGameOver) return;
    _isGameOver = true;

    // Pause background music before game over sound
    _backgroundMusicPlayer.pause();

    _stopwatch.stop();
    setState(() {
      _score = finalScore;
    });

    // Play game over sound
    _playGameOverSound();

    // Show dialog immediately, submit score in background
    _showGameOverDialog();
    _submitScoreInBackground();
  }

  Future<void> _loadBackgroundMusic() async {
    if (widget.settings.backgroundMusicUrl.isEmpty) {
      debugPrint('No background music URL provided');
      return;
    }

    try {
      debugPrint('Loading background music from: ${widget.settings.backgroundMusicUrl}');
      await _backgroundMusicPlayer.setUrl(widget.settings.backgroundMusicUrl);
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);
      debugPrint('Background music loaded successfully');
    } catch (e) {
      debugPrint('Error loading background music: $e');
    }
  }

  Future<void> _loadPipePassedSound() async {
    if (widget.settings.pipePassedSoundUrl.isEmpty) return;

    try {
      await _pipePassedSoundPlayer.setUrl(widget.settings.pipePassedSoundUrl);
      debugPrint('Pipe passed sound loaded successfully');
    } catch (e) {
      debugPrint('Error loading pipe passed sound: $e');
    }
  }

  Future<void> _playPipePassedSound() async {
    if (widget.settings.pipePassedSoundUrl.isEmpty) return;

    try {
      await _pipePassedSoundPlayer.stop();
      await _pipePassedSoundPlayer.seek(Duration.zero);
      await _pipePassedSoundPlayer.play();
    } catch (e) {
      debugPrint('Error playing pipe passed sound: $e');
    }
  }

  Future<void> _preLoadGameOverSound() async {
    try {
      // Use character's sound if available, otherwise use default
      final soundUrl = widget.selectedCharacter.gameOverSoundUrl.isNotEmpty
          ? widget.selectedCharacter.gameOverSoundUrl
          : widget.settings.defaultGameOverSoundUrl;

      if (soundUrl.isEmpty) {
        debugPrint('No game over sound configured');
        return;
      }

      await _audioPlayer.setUrl(soundUrl);
      debugPrint('Game over sound pre-loaded successfully: $soundUrl');
    } catch (e) {
      debugPrint('Error pre-loading game over sound: $e');
    }
  }

  Future<void> _playGameOverSound() async {
    try {
      // Stop, seek to beginning, and play (file is already loaded)
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing game over sound: $e');
    }
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _isGameOver = false; // Reset game over flag for next attempt
    });
    _game.reset();
    _stopwatch.reset();

    // Resume background music after reset
    if (widget.settings.backgroundMusicUrl.isNotEmpty) {
      _backgroundMusicPlayer.play();
    }
  }

  void _startGame() async {
    if (!_game.isGameStarted) {
      _stopwatch.start();

      // Start playing background music when game starts
      if (widget.settings.backgroundMusicUrl.isNotEmpty) {
        try {
          debugPrint('Attempting to play background music...');
          await _backgroundMusicPlayer.play();
          debugPrint('Background music playing');
        } catch (e) {
          debugPrint('Error playing background music: $e');
        }
      } else {
        debugPrint('No background music URL to play');
      }
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

      // Save final score to Firebase only when all attempts are done (competitive mode only)
      if (!hasMoreAttempts && widget.code != null) {
        final firestore = FirebaseFirestore.instance;
        final responseRef = firestore
            .collection('games')
            .doc(widget.gameId)
            .collection('responses')
            .doc(widget.code);

        await responseRef.update({
          'score': _bestScore,
          'score_timestamp': FieldValue.serverTimestamp(),
          'timeTakenSeconds': _stopwatch.elapsed.inSeconds,
          'lastPlayedAt': FieldValue.serverTimestamp(),
        });
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
      backgroundColor: Colors.black,
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
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent.shade200,
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black54,
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
                    style: TextStyle(
                      color: Colors.grey[200],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Start instruction (only show before first tap and after assets loaded)
              if (_currentAttempt == 0 && !_game.isGameStarted && !_isLoading)
                Center(
                  child: Text(
                    'Tap to Start',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[100],
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black54,
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
                      Icon(
                        Icons.person,
                        color: Colors.redAccent.shade200,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.userName,
                        style: TextStyle(
                          color: Colors.grey[100],
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
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.redAccent.shade200,
                    size: 32,
                  ),
                  onPressed: () {
                    if (_game.isGameStarted && !_game.isGameOver) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            'Exit Game?',
                            style: TextStyle(
                              color: Colors.redAccent.shade200,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'Your current game will not be saved.',
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[300],
                              ),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent.shade200,
                              ),
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

              // Loading overlay
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.redAccent.shade200,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading game assets...',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 18,
                            ),
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
    );
  }
}
