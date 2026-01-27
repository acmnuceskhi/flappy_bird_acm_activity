import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_settings.dart';

class FlappyBirdGame extends FlameGame with HasCollisionDetection {
  final GameSettings settings;
  final Function(int score) onGameOver;
  final Function() onScoreUpdate;
  
  late BirdComponent bird;
  final List<PipeComponent> pipes = [];
  bool isGameStarted = false;
  bool isGameOver = false;
  int score = 0;
  double timeSinceLastPipe = 0;
  final Random random = Random();

  FlappyBirdGame({
    required this.settings,
    required this.onGameOver,
    required this.onScoreUpdate,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Add bird
    bird = BirdComponent(
      position: Vector2(size.x * 0.2, size.y / 2),
      settings: settings,
    );
    add(bird);
    
    // Add ground
    add(GroundComponent());
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
  double velocity = 0;
  bool isActive = false;

  BirdComponent({
    required super.position,
    required this.settings,
  }) : super(size: Vector2.all(40));

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
    
    // Draw bird
    final paint = Paint()..color = Colors.yellow.shade700;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      paint,
    );

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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, gapY),
      pipePaint,
    );

    // Bottom pipe
    canvas.drawRect(
      Rect.fromLTWH(0, gapY + gapHeight, width, screenHeight - (gapY + gapHeight)),
      pipePaint,
    );

    // Pipe borders
    final borderPaint = Paint()
      ..color = Colors.green.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, gapY),
      borderPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, gapY + gapHeight, width, screenHeight - (gapY + gapHeight)),
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint,
    );
  }
}
