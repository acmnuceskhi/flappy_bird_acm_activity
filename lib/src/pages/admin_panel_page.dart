import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../models/character.dart';
import '../models/game_settings.dart';

/// Admin panel for managing characters and background
class AdminPanelPage extends StatefulWidget {
  final String gameId;
  final GameSettings settings;

  const AdminPanelPage({
    super.key,
    required this.gameId,
    required this.settings,
  });

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _characterNameCtrl = TextEditingController();
  final _pipeSpeedCtrl = TextEditingController(text: '3.0');
  final _jumpForceCtrl = TextEditingController(text: '8.0');
  final _backgroundUrlCtrl = TextEditingController();

  bool _uploading = false;
  PlatformFile? _selectedCharacterSprite;
  PlatformFile? _selectedBackground;
  PlatformFile? _selectedGameOverSound;

  @override
  void initState() {
    super.initState();
    _backgroundUrlCtrl.text = widget.settings.backgroundUrl;
  }

  @override
  void dispose() {
    _characterNameCtrl.dispose();
    _pipeSpeedCtrl.dispose();
    _jumpForceCtrl.dispose();
    _backgroundUrlCtrl.dispose();
    super.dispose();
  }

  Future<List<Character>> _loadCharacters() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('characters')
          .orderBy('order')
          .get();

      return snapshot.docs.map((doc) => Character.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading characters: $e');
      return [];
    }
  }

  Future<void> _pickCharacterSprite() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedCharacterSprite = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedBackground = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickGameOverSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedGameOverSound = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<String> _uploadFile(PlatformFile file, String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);

      if (kIsWeb) {
        // Web upload
        await storageRef.putData(file.bytes!);
      } else {
        // Mobile/Desktop upload
        await storageRef.putFile(File(file.path!));
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _addCharacter() async {
    final name = _characterNameCtrl.text.trim();
    final pipeSpeed = double.tryParse(_pipeSpeedCtrl.text) ?? 3.0;
    final jumpForce = double.tryParse(_jumpForceCtrl.text) ?? 8.0;

    if (name.isEmpty) {
      _showError('Please enter a character name');
      return;
    }

    if (_selectedCharacterSprite == null) {
      _showError('Please select a character sprite');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Upload sprite to Firebase Storage
      final spriteUrl = await _uploadFile(
        _selectedCharacterSprite!,
        'flappy_bird/characters/${DateTime.now().millisecondsSinceEpoch}_${_selectedCharacterSprite!.name}',
      );

      // Upload game over sound if provided, otherwise use default storage path
      String gameOverSoundUrl = "";
      if (_selectedGameOverSound != null) {
        gameOverSoundUrl = await _uploadFile(
          _selectedGameOverSound!,
          'flappy_bird/sounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedGameOverSound!.name}',
        );
      } else {
        gameOverSoundUrl = await FirebaseStorage.instance.ref().child(
          'flappy_bird/Fahhh - QuickSounds.com.mp3',
        ).getDownloadURL();
      }

      // Get next order value
      final characters = await _loadCharacters();
      final nextOrder = characters.isEmpty ? 0 : characters.length;

      // Create character in Firestore
      final character = Character(
        id: '', // Will be set by Firestore
        name: name,
        spriteUrl: spriteUrl,
        pipeSpeed: pipeSpeed,
        jumpForce: jumpForce,
        order: nextOrder,
        gameOverSoundUrl: gameOverSoundUrl,
      );

      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('characters')
          .add(character.toFirestore());

      // Clear form
      _characterNameCtrl.clear();
      _pipeSpeedCtrl.text = '3.0';
      _jumpForceCtrl.text = '8.0';
      setState(() {
        _selectedCharacterSprite = null;
        _selectedGameOverSound = null;
      });

      _showSuccess('Character added successfully!');
    } catch (e) {
      _showError('Failed to add character: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadBackground() async {
    if (_selectedBackground == null) {
      _showError('Please select a background image');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Upload background to Firebase Storage
      final backgroundUrl = await _uploadFile(
        _selectedBackground!,
        'flappy_bird/backgrounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedBackground!.name}',
      );

      // Update settings document
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('settings')
          .doc('flappybird')
          .update({'backgroundUrl': backgroundUrl});

      setState(() {
        _backgroundUrlCtrl.text = backgroundUrl;
        _selectedBackground = null;
      });

      _showSuccess('Background updated successfully!');
    } catch (e) {
      _showError('Failed to upload background: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCharacter(String characterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('characters')
          .doc(characterId)
          .delete();

      _showSuccess('Character deleted');
    } catch (e) {
      _showError('Failed to delete character: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.redAccent.shade200,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.red.shade900],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Background Section
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Background',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_backgroundUrlCtrl.text.isNotEmpty)
                        Column(
                          children: [
                            Text(
                              'Current Background:',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _backgroundUrlCtrl.text,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    color: Colors.grey[800],
                                    child: Center(
                                      child: Text(
                                        'Failed to load image',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBackground == null
                                  ? 'No file selected'
                                  : _selectedBackground!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickBackground,
                            icon: Icon(Icons.folder_open, color: Colors.black),
                            label: Text('Choose File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploading ? null : _uploadBackground,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade200,
                            foregroundColor: Colors.black,
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text('Upload Background'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Add Character Section
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Character',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _characterNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Character Name',
                          filled: true,
                          fillColor: Colors.grey[850],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red.shade800),
                          ),
                          labelStyle: TextStyle(color: Colors.grey[300]),
                        ),
                        style: TextStyle(color: Colors.grey[100]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pipeSpeedCtrl,
                              decoration: InputDecoration(
                                labelText: 'Pipe Speed',
                                filled: true,
                                fillColor: Colors.grey[850],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade800,
                                  ),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[300]),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _jumpForceCtrl,
                              decoration: InputDecoration(
                                labelText: 'Jump Force',
                                filled: true,
                                fillColor: Colors.grey[850],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade800,
                                  ),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[300]),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCharacterSprite == null
                                  ? 'No sprite selected'
                                  : _selectedCharacterSprite!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickCharacterSprite,
                            icon: Icon(Icons.image, color: Colors.black),
                            label: Text('Choose Sprite'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedGameOverSound == null
                                  ? 'No game over sound (using default)'
                                  : _selectedGameOverSound!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickGameOverSound,
                            icon: Icon(Icons.music_note, color: Colors.black),
                            label: Text('Choose Sound'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploading ? null : _addCharacter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade200,
                            foregroundColor: Colors.black,
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text('Add Character'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Characters List
              Text(
                'Existing Characters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Character>>(
                future: _loadCharacters(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  final characters = snapshot.data ?? [];

                  if (characters.isEmpty) {
                    return Card(
                      color: Colors.grey[900],
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No characters added yet',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: characters.map((character) {
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: character.spriteUrl.isEmpty
                              ? Icon(
                                  Icons.flutter_dash,
                                  size: 40,
                                  color: Colors.grey[300],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    character.spriteUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey[400],
                                      );
                                    },
                                  ),
                                ),
                          title: Text(
                            character.name,
                            style: TextStyle(color: Colors.grey[100]),
                          ),
                          subtitle: Text(
                            'Speed: ${character.pipeSpeed} | Jump: ${character.jumpForce}',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  title: Text(
                                    'Delete Character?',
                                    style: TextStyle(
                                      color: Colors.redAccent.shade200,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete ${character.name}?',
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
                                        _deleteCharacter(character.id);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Colors.redAccent.shade200,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
