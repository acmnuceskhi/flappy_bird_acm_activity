import 'dart:ui';

/// Represents the player bird
class Bird {
  double y;
  double velocity;
  final double x;
  final double size;

  Bird({required this.y, this.velocity = 0.0, this.x = 0.2, this.size = 40.0});

  void jump(double jumpForce) {
    velocity = -jumpForce;
  }

  void update(double gravity) {
    velocity += gravity * 0.5;
    y += velocity;
  }

  Rect get hitbox => Rect.fromLTWH(x - size / 2, y - size / 2, size, size);
}

/// Represents a pipe obstacle
class Pipe {
  final double x;
  final double gapY;
  final double gapHeight;
  final double width;
  bool passed;

  Pipe({
    required this.x,
    required this.gapY,
    this.gapHeight = 200.0,
    this.width = 80.0,
    this.passed = false,
  });

  Pipe copyWith({
    double? x,
    double? gapY,
    double? gapHeight,
    double? width,
    bool? passed,
  }) {
    return Pipe(
      x: x ?? this.x,
      gapY: gapY ?? this.gapY,
      gapHeight: gapHeight ?? this.gapHeight,
      width: width ?? this.width,
      passed: passed ?? this.passed,
    );
  }

  // Top pipe hitbox
  Rect get topHitbox => Rect.fromLTWH(x, 0, width, gapY);

  // Bottom pipe hitbox (from gap end to screen bottom)
  Rect bottomHitbox(double screenHeight) => Rect.fromLTWH(
    x,
    gapY + gapHeight,
    width,
    screenHeight - (gapY + gapHeight),
  );
}
