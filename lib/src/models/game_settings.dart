/// Game settings loaded from Firestore or defaults
class GameSettings {
  final int maxAttempts;
  final double gravity;
  final double pipeSpeed;
  final double pipeSpawnInterval;

  GameSettings({
    this.maxAttempts = 3,
    this.gravity = 0.5,
    this.pipeSpeed = 3.0,
    this.pipeSpawnInterval = 2.0,
  });

  factory GameSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return GameSettings();
    }
    return GameSettings(
      maxAttempts: data['maxAttempts'] as int? ?? 3,
      gravity: (data['gravity'] as num?)?.toDouble() ?? 0.5,
      pipeSpeed: (data['pipeSpeed'] as num?)?.toDouble() ?? 3.0,
      pipeSpawnInterval:
          (data['pipeSpawnInterval'] as num?)?.toDouble() ?? 2.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'maxAttempts': maxAttempts,
      'gravity': gravity,
      'pipeSpeed': pipeSpeed,
      'pipeSpawnInterval': pipeSpawnInterval,
    };
  }
}
