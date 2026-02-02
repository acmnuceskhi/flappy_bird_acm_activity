import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'character_selection_page.dart';
import 'flappy_game_page.dart';
import '../models/game_settings.dart';
import '../models/character.dart';

/// Code entry page - user enters their registration code
class CodeEntryPage extends StatefulWidget {
  final bool isCompetitiveMode;

  const CodeEntryPage({super.key, this.isCompetitiveMode = true});

  @override
  State<CodeEntryPage> createState() => _CodeEntryPageState();
}

class _CodeEntryPageState extends State<CodeEntryPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndStart() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Query for game named "Flappy Bird"
      final gameQuery = await firestore
          .collection('games')
          .where('name', isEqualTo: 'Flappy Bird')
          .limit(1)
          .get();

      if (gameQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Flappy Bird game not found. Please contact admin.';
          _isLoading = false;
        });
        return;
      }

      final gameDoc = gameQuery.docs.first;
      final gameId = gameDoc.id;

      // Check if code exists in responses
      final responseRef = firestore
          .collection('games')
          .doc(gameId)
          .collection('responses')
          .doc(code);
      final responseDoc = await responseRef.get();

      if (!responseDoc.exists) {
        setState(() {
          _errorMessage = 'Invalid code. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      final responseData = responseDoc.data() as Map<String, dynamic>;

      // Check if user has already played (score field exists and is not null)
      final score = responseData['score'];
      final hasPlayed = score != null;

      // Load game settings
      final settingsDoc = await firestore
          .collection('games')
          .doc(gameId)
          .collection('settings')
          .doc('flappybird')
          .get();

      final settings = GameSettings.fromFirestore(settingsDoc.data());

      if (hasPlayed) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Already Played',
              style: TextStyle(
                color: Colors.redAccent.shade200,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have already completed this game.\n\nYour score: ${responseData['score'] ?? 0}',
              style: TextStyle(color: Colors.grey[300]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent.shade200,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // For competitive mode, go directly to game with default character
      // For casual mode (non-competitive), go to character selection
      if (!mounted) return;

      if (widget.isCompetitiveMode) {
        // Competitive mode: use default character
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlappyGamePage(
              gameId: gameId,
              code: code,
              settings: settings,
              userName: responseData['userName'] as String? ?? 'Player',
              selectedCharacter: Character.defaultBird,
            ),
          ),
        );
      } else {
        // Casual mode: allow character selection
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CharacterSelectionPage(
              gameId: gameId,
              code: code,
              settings: settings,
              userName: responseData['userName'] as String? ?? 'Player',
            ),
          ),
        );
      }

      // Clear code after returning from game
      _codeController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.isCompetitiveMode
          ? AppBar(
              title: const Text('Enter Competition Code'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.red.shade900],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _buildCodeEntryForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntryForm(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.shade800.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.gamepad, size: 84, color: Colors.redAccent.shade200),
            const SizedBox(height: 18),
            Text(
              'Flappy Bird Challenge',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent.shade200, // Red flappy text
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your registration code to play',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[300]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Registration Code',
                hintText: 'Enter code',
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade800),
                ),
                prefixIcon: Icon(
                  Icons.vpn_key,
                  color: Colors.redAccent.shade200,
                ),
                labelStyle: TextStyle(color: Colors.grey[300]),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: TextStyle(color: Colors.grey[100]),
              textCapitalization: TextCapitalization.characters,
              enabled: !_isLoading,
              onSubmitted: (_) => _validateAndStart(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade50),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isLoading ? null : _validateAndStart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.redAccent.shade200,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      'Start Game',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
