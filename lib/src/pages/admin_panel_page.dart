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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Background Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Game Background',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_backgroundUrlCtrl.text.isNotEmpty)
                      Column(
                        children: [
                          const Text('Current Background:'),
                          const SizedBox(height: 8),
                          Image.network(
                            _backgroundUrlCtrl.text,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Text('Failed to load image'),
                                ),
                              );
                            },
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
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _uploading ? null : _pickBackground,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Choose File'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _uploadBackground,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: _uploading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Character',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _characterNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Character Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pipeSpeedCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Pipe Speed',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _jumpForceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Jump Force',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
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
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _uploading ? null : _pickCharacterSprite,
                          icon: const Icon(Icons.image),
                          label: const Text('Choose Sprite'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _addCharacter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: _uploading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
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
            const Text(
              'Existing Characters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Character>>(
              future: _loadCharacters(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final characters = snapshot.data ?? [];

                if (characters.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No characters added yet')),
                    ),
                  );
                }

                return Column(
                  children: characters.map((character) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: character.spriteUrl.isEmpty
                            ? const Icon(Icons.flutter_dash, size: 40)
                            : Image.network(
                                character.spriteUrl,
                                width: 40,
                                height: 40,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  );
                                },
                              ),
                        title: Text(character.name),
                        subtitle: Text(
                          'Speed: ${character.pipeSpeed} | Jump: ${character.jumpForce}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Character?'),
                                content: Text(
                                  'Are you sure you want to delete ${character.name}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteCharacter(character.id);
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
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
    );
  }
}
