import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a playable character with custom sprite and physics
class Character {
  final String id;
  final String name;
  final String spriteUrl;  // Firebase Storage URL
  final double pipeSpeed;
  final double jumpForce;
  final int order;  // For displaying in consistent order

  const Character({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.pipeSpeed,
    required this.jumpForce,
    this.order = 0,
  });

  /// Create from Firestore document
  factory Character.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Character(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed',
      spriteUrl: data['spriteUrl'] as String? ?? '',
      pipeSpeed: (data['pipeSpeed'] as num?)?.toDouble() ?? 3.0,
      jumpForce: (data['jumpForce'] as num?)?.toDouble() ?? 8.0,
      order: data['order'] as int? ?? 0,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'spriteUrl': spriteUrl,
      'pipeSpeed': pipeSpeed,
      'jumpForce': jumpForce,
      'order': order,
    };
  }

  /// Default bird character (fallback)
  static const Character defaultBird = Character(
    id: 'default',
    name: 'Classic Bird',
    spriteUrl: '',  // Will use built-in rendering
    pipeSpeed: 3.0,
    jumpForce: 8.0,
    order: 0,
  );

  Character copyWith({
    String? id,
    String? name,
    String? spriteUrl,
    double? pipeSpeed,
    double? jumpForce,
    int? order,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      spriteUrl: spriteUrl ?? this.spriteUrl,
      pipeSpeed: pipeSpeed ?? this.pipeSpeed,
      jumpForce: jumpForce ?? this.jumpForce,
      order: order ?? this.order,
    );
  }
}
