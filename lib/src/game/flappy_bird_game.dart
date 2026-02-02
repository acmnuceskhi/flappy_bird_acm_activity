import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/game_settings.dart';

class FlappyBirdGame extends FlameGame with HasCollisionDetection {
  final GameSettings settings;
  final Function(int score) onGameOver;
  final Function() onScoreUpdate;
  final Function()? onPipePassed;
  final String? characterSpriteUrl;

  late BirdComponent bird;
  final List<PipeComponent> pipes = [];
  bool isGameStarted = false;
  bool isGameOver = false;
  bool isAssetsLoaded = false; // Track asset loading status
  int score = 0;
  double timeSinceLastPipe = 0;
  final Random random = Random();

  FlappyBirdGame({
    required this.settings,
    required this.onGameOver,
    required this.onScoreUpdate,
    this.onPipePassed,
    this.characterSpriteUrl,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add bird with sprite URL
    bird = BirdComponent(
      position: Vector2(size.x * 0.2, size.y / 2),
      settings: settings,
      spriteUrl: characterSpriteUrl,
    );
    await add(bird);

    // Add ground
    add(GroundComponent());

    // Mark assets as loaded after bird sprite loads
    isAssetsLoaded = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isGameStarted || isGameOver) return;

    // Spawn pipes
    timeSinceLastPipe += dt;
    if (timeSinceLastPipe >= settings.pipeSpawnInterval) {
      _spawnPipe();
      timeSinceLastPipe = 0;
    }

    // Remove off-screen pipes
    pipes.removeWhere((pipe) {
      if (pipe.position.x < -100) {
        pipe.removeFromParent();
        return true;
      }
      return false;
    });

    // Check if bird passed pipes and increment score
    for (final pipe in pipes) {
      if (!pipe.passed && pipe.position.x + pipe.width < bird.position.x) {
        pipe.passed = true;
        score++;
        onScoreUpdate();
        onPipePassed?.call();
      }
    }

    // Check boundaries
    if (bird.position.y < 0 || bird.position.y > size.y - 100) {
      _triggerGameOver();
    }
  }

  void _spawnPipe() {
    final gapY = 150.0 + random.nextDouble() * (size.y - 450);
    final pipe = PipeComponent(
      position: Vector2(size.x + 50, 0),
      gapY: gapY,
      gapHeight: 200,
      screenHeight: size.y,
      settings: settings,
      bird: bird,
      onCollision: _triggerGameOver,
    );
    add(pipe);
    pipes.add(pipe);
  }

  void _triggerGameOver() {
    if (isGameOver) return;
    isGameOver = true;
    onGameOver(score);
  }

  void handleTap() {
    if (isGameOver) return;

    if (!isGameStarted) {
      isGameStarted = true;
      bird.isActive = true;
      // Spawn the first pipe immediately
      _spawnPipe();
      timeSinceLastPipe = 0;
    }

    bird.jump();
  }

  void reset() {
    isGameStarted = false;
    isGameOver = false;
    score = 0;
    timeSinceLastPipe = 0;

    // Remove all pipes
    for (final pipe in pipes) {
      pipe.removeFromParent();
    }
    pipes.clear();

    // Reset bird
    bird.position = Vector2(size.x * 0.2, size.y / 2);
    bird.velocity = 0;
    bird.isActive = false;
  }
}

class BirdComponent extends PositionComponent {
  final GameSettings settings;
  final String? spriteUrl;
  double velocity = 0;
  bool isActive = false;
  ui.Image? _spriteImage; // Use dart:ui Image type explicitly

  BirdComponent({
    required super.position,
    required this.settings,
    this.spriteUrl,
  }) : super(size: Vector2.all(60));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load custom sprite if URL provided
    if (spriteUrl != null && spriteUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(spriteUrl!));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          _spriteImage = frame.image;
        }
      } catch (e) {
        debugPrint('Failed to load sprite: $e');
      }
    }
  }

  void jump() {
    velocity = -settings.jumpForce;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Only apply physics when active (game started)
    if (!isActive) return;

    velocity += settings.gravity * dt * 50;
    position.y += velocity * dt * 50;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // If custom sprite is loaded, draw it clipped to a circle
    if (_spriteImage != null) {
      canvas.save();

      // Create circular clip path
      final center = Offset(size.x / 2, size.y / 2);
      final radius = size.x / 2;
      final circlePath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.clipPath(circlePath);

      // Draw the image to fill the circle
      final srcRect = Rect.fromLTWH(
        0,
        0,
        _spriteImage!.width.toDouble(),
        _spriteImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawImageRect(_spriteImage!, srcRect, dstRect, Paint());

      canvas.restore();

      // Draw border around the circle
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, borderPaint);
    } else {
      // Default bird rendering (yellow circle)
      final paint = Paint()..color = Colors.yellow.shade700;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);

      // Bird border
      final borderPaint = Paint()
        ..color = Colors.orange.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        borderPaint,
      );

      // Draw wing after the bird body (on the back)
      _drawWing(canvas);
    }
  }

  void _drawWing(Canvas canvas) {
    // Wing rotation based on velocity
    // Falling (positive velocity) -> wing flaps up (positive rotation)
    // Going up (negative velocity) -> wing flaps down (negative rotation)
    final wingRotation = (velocity / settings.jumpForce) * 0.5;

    final wingPaint = Paint()
      ..color = Colors.orange.shade700
      ..style = PaintingStyle.fill;

    final wingBorderPaint = Paint()
      ..color = Colors.orange.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Wing position (center-back of bird)
    final wingX = size.x * 0.3;
    final wingY = size.y * 0.5;

    canvas.save();
    canvas.translate(wingX, wingY);
    canvas.rotate(wingRotation);

    // Wing shape (ellipse)
    final wingPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.fromDirection(pi) * size.x / 2,
          width: size.x * 0.4,
          height: size.y * 0.6,
        ),
      );

    canvas.drawPath(wingPath, wingPaint);
    canvas.drawPath(wingPath, wingBorderPaint);

    canvas.restore();
  }
}

class PipeComponent extends PositionComponent {
  final double gapY;
  final double gapHeight;
  final double screenHeight;
  final GameSettings settings;
  final BirdComponent bird;
  final VoidCallback onCollision;
  bool passed = false;
  final double width = 80;

  PipeComponent({
    required super.position,
    required this.gapY,
    required this.gapHeight,
    required this.screenHeight,
    required this.settings,
    required this.bird,
    required this.onCollision,
  }) : super(size: Vector2(80, screenHeight));

  @override
  void update(double dt) {
    super.update(dt);

    position.x -= settings.pipeSpeed * dt * 100;

    // Check collision with bird
    final birdLeft = bird.position.x;
    final birdRight = bird.position.x + bird.size.x;
    final birdTop = bird.position.y;
    final birdBottom = bird.position.y + bird.size.y;

    final pipeLeft = position.x;
    final pipeRight = position.x + width;

    // Check if bird is within pipe's horizontal bounds
    if (birdRight > pipeLeft && birdLeft < pipeRight) {
      // Check if bird hits top or bottom pipe
      if (birdTop < gapY || birdBottom > gapY + gapHeight) {
        onCollision();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pipePaint = Paint()..color = Colors.green.shade700;

    // Top pipe
    canvas.drawRect(Rect.fromLTWH(0, 0, width, gapY), pipePaint);

    // Bottom pipe
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        gapY + gapHeight,
        width,
        screenHeight - (gapY + gapHeight),
      ),
      pipePaint,
    );

    // Pipe borders
    final borderPaint = Paint()
      ..color = Colors.green.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, gapY), borderPaint);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        gapY + gapHeight,
        width,
        screenHeight - (gapY + gapHeight),
      ),
      borderPaint,
    );
  }
}

class GroundComponent extends PositionComponent {
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(0, size.y - 100);
    this.size = Vector2(size.x, 100);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()..color = Colors.brown.shade700;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
