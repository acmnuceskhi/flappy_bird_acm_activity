import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'character_selection_page.dart';
import '../models/game_settings.dart';

/// Code entry page - user enters their registration code
class CodeEntryPage extends StatefulWidget {
  const CodeEntryPage({super.key});

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
            title: const Text('Already Played'),
            content: Text(
              'You have already completed this game.\n\n'
              'Your score: ${responseData['score'] ?? 0}',
            ),
            // ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
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

      // Navigate to character selection
      if (!mounted) return;
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.gamepad, size: 100, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Flappy Bird Challenge',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter your registration code to play',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Registration Code',
                  hintText: 'Enter code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: !_isLoading,
                onSubmitted: (_) => _validateAndStart(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _validateAndStart,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Start Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
