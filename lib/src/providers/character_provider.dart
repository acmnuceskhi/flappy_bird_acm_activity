import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/character.dart';

/// Provider for managing character state with local caching
class CharacterProvider with ChangeNotifier {
  List<Character> _characters = [];
  bool _isLoading = false;
  String? _error;
  String? _gameId;

  List<Character> get characters => _characters;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCharacters => _characters.isNotEmpty;

  /// Load characters from Firestore (or use cached if already loaded)
  Future<void> loadCharacters(
    String gameId, {
    bool forceRefresh = false,
  }) async {
    // If already loaded and not forcing refresh, return cached
    if (_characters.isNotEmpty && !forceRefresh && _gameId == gameId) {
      return;
    }

    _gameId = gameId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('characters')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty) {
        _characters = [Character.defaultBird];
      } else {
        _characters = snapshot.docs
            .map((doc) => Character.fromFirestore(doc))
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _characters = [Character.defaultBird];
      notifyListeners();
      debugPrint('Error loading characters: $e');
    }
  }

  /// Add a new character
  Future<void> addCharacter(String gameId, Character character) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('characters')
          .add(character.toFirestore());

      // Add to local cache with the new ID
      final newCharacter = character.copyWith(id: docRef.id);
      _characters.add(newCharacter);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding character: $e');
      rethrow;
    }
  }

  /// Update an existing character
  Future<void> updateCharacter(String gameId, Character character) async {
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('characters')
          .doc(character.id)
          .update(character.toFirestore());

      // Update in local cache
      final index = _characters.indexWhere((c) => c.id == character.id);
      if (index != -1) {
        _characters[index] = character;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating character: $e');
      rethrow;
    }
  }

  /// Delete a character
  Future<void> deleteCharacter(String gameId, String characterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('characters')
          .doc(characterId)
          .delete();

      // Remove from local cache
      _characters.removeWhere((c) => c.id == characterId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting character: $e');
      rethrow;
    }
  }

  /// Force refresh characters from Firestore
  Future<void> refresh(String gameId) async {
    await loadCharacters(gameId, forceRefresh: true);
  }

  /// Clear cached characters (e.g., on logout)
  void clear() {
    _characters = [];
    _gameId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
