import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/game_settings.dart';
import '../providers/character_provider.dart';

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
  final _backgroundMusicUrlCtrl = TextEditingController();
  final _pipePassedSoundUrlCtrl = TextEditingController();
  final _defaultGameOverSoundUrlCtrl = TextEditingController();

  bool _uploading = false;
  PlatformFile? _selectedCharacterSprite;
  Uint8List? _editedCharacterSpriteBytes; // Store edited image bytes
  PlatformFile? _selectedBackground;
  PlatformFile? _selectedBackgroundMusic;
  PlatformFile? _selectedPipePassedSound;
  PlatformFile? _selectedDefaultGameOverSound;
  PlatformFile? _selectedGameOverSound;

  @override
  void initState() {
    super.initState();
    _backgroundUrlCtrl.text = widget.settings.backgroundUrl;
    _backgroundMusicUrlCtrl.text = widget.settings.backgroundMusicUrl;
    _pipePassedSoundUrlCtrl.text = widget.settings.pipePassedSoundUrl;
    _defaultGameOverSoundUrlCtrl.text = widget.settings.defaultGameOverSoundUrl;

    // Load characters if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      if (!provider.hasCharacters || provider.error != null) {
        provider.loadCharacters(widget.gameId);
      }
    });
  }

  @override
  void dispose() {
    _characterNameCtrl.dispose();
    _pipeSpeedCtrl.dispose();
    _jumpForceCtrl.dispose();
    _backgroundUrlCtrl.dispose();
    _backgroundMusicUrlCtrl.dispose();
    _pipePassedSoundUrlCtrl.dispose();
    _defaultGameOverSoundUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCharacterSprite() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _selectedCharacterSprite = file;
          _editedCharacterSpriteBytes = file.bytes;
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

  Future<void> _pickBackgroundMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedBackgroundMusic = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickPipePassedSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPipePassedSound = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickDefaultGameOverSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedDefaultGameOverSound = result.files.first;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<String> _uploadFile(
    PlatformFile file,
    String path, {
    Uint8List? customBytes,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);

      debugPrint('Uploading file to: $path');
      debugPrint('Has custom bytes: ${customBytes != null}');
      debugPrint('Custom bytes length: ${customBytes?.length ?? 0}');
      debugPrint('File bytes length: ${file.bytes?.length ?? 0}');

      // Create metadata for proper content type
      final metadata = SettableMetadata(
        contentType: customBytes != null
            ? 'image/png'
            : (file.extension != null
                  ? 'image/${file.extension}'
                  : 'application/octet-stream'),
      );

      if (kIsWeb) {
        // Web upload - use custom bytes if provided, otherwise use file bytes
        final bytesToUpload = customBytes ?? file.bytes;
        if (bytesToUpload == null) {
          throw Exception('No bytes available for upload');
        }
        await storageRef.putData(bytesToUpload, metadata);
      } else {
        // Mobile/Desktop upload
        if (customBytes != null) {
          // Use custom bytes if provided
          await storageRef.putData(customBytes, metadata);
        } else {
          // Otherwise use file path
          if (file.path == null) {
            throw Exception('No file path available for upload');
          }
          await storageRef.putFile(File(file.path!), metadata);
        }
      }

      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint('Upload successful. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
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

    if (_editedCharacterSpriteBytes == null) {
      _showError('Please wait for image processing to complete');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Upload sprite to Firebase Storage (use edited bytes if available)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _selectedCharacterSprite!.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final spriteUrl = await _uploadFile(
        _selectedCharacterSprite!,
        'flappy_bird/characters/${timestamp}_$fileName',
        customBytes: _editedCharacterSpriteBytes,
      );

      // Upload game over sound if provided, otherwise use default from settings
      String gameOverSoundUrl = "";
      if (_selectedGameOverSound != null) {
        gameOverSoundUrl = await _uploadFile(
          _selectedGameOverSound!,
          'flappy_bird/sounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedGameOverSound!.name}',
        );
      } else {
        // Use the default game over sound from settings
        gameOverSoundUrl = _defaultGameOverSoundUrlCtrl.text;
      }

      // Get next order value
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      final nextOrder = provider.characters.isEmpty
          ? 0
          : provider.characters.length;

      // Create character
      final character = Character(
        id: '', // Will be set by Firestore
        name: name,
        spriteUrl: spriteUrl,
        pipeSpeed: pipeSpeed,
        jumpForce: jumpForce,
        order: nextOrder,
        gameOverSoundUrl: gameOverSoundUrl,
      );

      // Add via provider (updates local cache and Firestore)
      await provider.addCharacter(widget.gameId, character);

      // Clear form
      _characterNameCtrl.clear();
      _pipeSpeedCtrl.text = '3.0';
      _jumpForceCtrl.text = '8.0';
      setState(() {
        _selectedCharacterSprite = null;
        _editedCharacterSpriteBytes = null;
        _selectedGameOverSound = null;
      });

      _showSuccess('Character added successfully!');
    } catch (e, stackTrace) {
      debugPrint('Error adding character: $e');
      debugPrint('Stack trace: $stackTrace');
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
      // Delete old background if it exists
      final oldBackgroundUrl = _backgroundUrlCtrl.text;
      if (oldBackgroundUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldBackgroundUrl).delete();
          debugPrint('Old background deleted successfully');
        } catch (e) {
          debugPrint('Error deleting old background: $e');
        }
      }

      // Upload new background to Firebase Storage
      final backgroundUrl = await _uploadFile(
        _selectedBackground!,
        'flappy_bird/backgrounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedBackground!.name}',
      );

      // Update settings document (or create if it doesn't exist)
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('settings')
          .doc('flappybird')
          .set({'backgroundUrl': backgroundUrl}, SetOptions(merge: true));

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

  Future<void> _uploadBackgroundMusic() async {
    if (_selectedBackgroundMusic == null) {
      _showError('Please select a music file');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Delete old background music if it exists
      final oldMusicUrl = _backgroundMusicUrlCtrl.text;
      if (oldMusicUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldMusicUrl).delete();
          debugPrint('Old background music deleted successfully');
        } catch (e) {
          debugPrint('Error deleting old music: $e');
        }
      }

      // Upload new background music to Firebase Storage
      final musicUrl = await _uploadFile(
        _selectedBackgroundMusic!,
        'flappy_bird/music/${DateTime.now().millisecondsSinceEpoch}_${_selectedBackgroundMusic!.name}',
      );

      // Update settings document (or create if it doesn't exist)
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('settings')
          .doc('flappybird')
          .set({'backgroundMusicUrl': musicUrl}, SetOptions(merge: true));

      setState(() {
        _backgroundMusicUrlCtrl.text = musicUrl;
        _selectedBackgroundMusic = null;
      });

      _showSuccess('Background music updated successfully!');
    } catch (e) {
      _showError('Failed to upload background music: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadPipePassedSound() async {
    if (_selectedPipePassedSound == null) {
      _showError('Please select a sound file');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Delete old pipe passed sound if it exists
      final oldSoundUrl = _pipePassedSoundUrlCtrl.text;
      if (oldSoundUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldSoundUrl).delete();
          debugPrint('Old pipe passed sound deleted successfully');
        } catch (e) {
          debugPrint('Error deleting old sound: $e');
        }
      }

      // Upload new pipe passed sound to Firebase Storage
      final soundUrl = await _uploadFile(
        _selectedPipePassedSound!,
        'flappy_bird/sounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedPipePassedSound!.name}',
      );

      // Update settings document (or create if it doesn't exist)
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('settings')
          .doc('flappybird')
          .set({'pipePassedSoundUrl': soundUrl}, SetOptions(merge: true));

      setState(() {
        _pipePassedSoundUrlCtrl.text = soundUrl;
        _selectedPipePassedSound = null;
      });

      _showSuccess('Pipe passed sound updated successfully!');
    } catch (e) {
      _showError('Failed to upload pipe passed sound: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadDefaultGameOverSound() async {
    if (_selectedDefaultGameOverSound == null) {
      _showError('Please select a sound file');
      return;
    }

    setState(() => _uploading = true);

    try {
      // Delete old default game over sound if it exists
      final oldSoundUrl = _defaultGameOverSoundUrlCtrl.text;
      if (oldSoundUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldSoundUrl).delete();
          debugPrint('Old default game over sound deleted successfully');
        } catch (e) {
          debugPrint('Error deleting old sound: $e');
        }
      }

      // Upload new default game over sound to Firebase Storage
      final soundUrl = await _uploadFile(
        _selectedDefaultGameOverSound!,
        'flappy_bird/sounds/${DateTime.now().millisecondsSinceEpoch}_${_selectedDefaultGameOverSound!.name}',
      );

      // Update settings document (or create if it doesn't exist)
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('settings')
          .doc('flappybird')
          .set({'defaultGameOverSoundUrl': soundUrl}, SetOptions(merge: true));

      setState(() {
        _defaultGameOverSoundUrlCtrl.text = soundUrl;
        _selectedDefaultGameOverSound = null;
      });

      _showSuccess('Default game over sound updated successfully!');
    } catch (e) {
      _showError('Failed to upload default game over sound: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCharacter(
    String characterId,
    String spriteUrl,
    String soundUrl,
  ) async {
    try {
      final provider = Provider.of<CharacterProvider>(context, listen: false);

      // Delete character via provider (updates local cache and Firestore)
      await provider.deleteCharacter(widget.gameId, characterId);

      // Delete sprite from storage if it exists
      if (spriteUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(spriteUrl).delete();
        } catch (e) {
          debugPrint('Error deleting sprite: $e');
        }
      }

      // Delete sound from storage if it exists and is not the default
      if (soundUrl.isNotEmpty &&
          !soundUrl.contains('Fahhh - QuickSounds.com')) {
        try {
          await FirebaseStorage.instance.refFromURL(soundUrl).delete();
        } catch (e) {
          debugPrint('Error deleting sound: $e');
        }
      }

      _showSuccess('Character deleted');
    } catch (e) {
      _showError('Failed to delete character: $e');
    }
  }

  Future<void> _editCharacter(Character character) async {
    final nameCtrl = TextEditingController(text: character.name);
    final speedCtrl = TextEditingController(
      text: character.pipeSpeed.toString(),
    );
    final jumpCtrl = TextEditingController(
      text: character.jumpForce.toString(),
    );
    PlatformFile? newSprite;
    Uint8List? editedSpriteBytes;
    PlatformFile? newSound;
    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Edit Character',
            style: TextStyle(
              color: Colors.redAccent.shade200,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Character Name',
                    filled: true,
                    fillColor: Colors.grey[850],
                    labelStyle: TextStyle(color: Colors.grey[300]),
                  ),
                  style: TextStyle(color: Colors.grey[100]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: speedCtrl,
                  decoration: InputDecoration(
                    labelText: 'Pipe Speed',
                    filled: true,
                    fillColor: Colors.grey[850],
                    labelStyle: TextStyle(color: Colors.grey[300]),
                  ),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.grey[100]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: jumpCtrl,
                  decoration: InputDecoration(
                    labelText: 'Jump Force',
                    filled: true,
                    fillColor: Colors.grey[850],
                    labelStyle: TextStyle(color: Colors.grey[300]),
                  ),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.grey[100]),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Sprite:',
                  style: TextStyle(color: Colors.grey[300]),
                ),
                const SizedBox(height: 8),
                if (character.spriteUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      character.spriteUrl,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            setDialogState(() {
                              newSprite = file;
                              editedSpriteBytes = file.bytes;
                            });
                          }
                        },
                  icon: const Icon(Icons.image),
                  label: Text(
                    newSprite == null
                        ? 'Change Sprite'
                        : 'Sprite: ${newSprite!.name}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade200,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.audio,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              newSound = result.files.first;
                            });
                          }
                        },
                  icon: const Icon(Icons.music_note),
                  label: Text(
                    newSound == null
                        ? 'Change Sound'
                        : 'Sound: ${newSound!.name}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade200,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[300]),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);

                      try {
                        String spriteUrl = character.spriteUrl;
                        String soundUrl = character.gameOverSoundUrl;

                        // Upload new sprite if selected
                        if (newSprite != null) {
                          // Delete old sprite
                          if (character.spriteUrl.isNotEmpty) {
                            try {
                              await FirebaseStorage.instance
                                  .refFromURL(character.spriteUrl)
                                  .delete();
                            } catch (e) {
                              debugPrint('Error deleting old sprite: $e');
                            }
                          }

                          // Upload new sprite (use edited bytes if available)
                          spriteUrl = await _uploadFile(
                            newSprite!,
                            'flappy_bird/characters/${DateTime.now().millisecondsSinceEpoch}_${newSprite!.name}',
                            customBytes: editedSpriteBytes,
                          );
                        }

                        // Upload new sound if selected
                        if (newSound != null) {
                          // Delete old sound if it's not the default
                          if (character.gameOverSoundUrl.isNotEmpty &&
                              !character.gameOverSoundUrl.contains(
                                'Fahhh - QuickSounds.com',
                              )) {
                            try {
                              await FirebaseStorage.instance
                                  .refFromURL(character.gameOverSoundUrl)
                                  .delete();
                            } catch (e) {
                              debugPrint('Error deleting old sound: $e');
                            }
                          }

                          // Upload new sound
                          soundUrl = await _uploadFile(
                            newSound!,
                            'flappy_bird/sounds/${DateTime.now().millisecondsSinceEpoch}_${newSound!.name}',
                          );
                        }

                        // Update character document
                        final updatedCharacter = character.copyWith(
                          name: nameCtrl.text.trim(),
                          pipeSpeed:
                              double.tryParse(speedCtrl.text) ??
                              character.pipeSpeed,
                          jumpForce:
                              double.tryParse(jumpCtrl.text) ??
                              character.jumpForce,
                          spriteUrl: spriteUrl,
                          gameOverSoundUrl: soundUrl,
                        );

                        // Update via provider (updates local cache and Firestore)
                        final provider = Provider.of<CharacterProvider>(
                          context,
                          listen: false,
                        );
                        await provider.updateCharacter(
                          widget.gameId,
                          updatedCharacter,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _showSuccess('Character updated successfully!');
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _showError('Failed to update character: $e');
                      }
                    },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent.shade200,
              ),
              child: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    speedCtrl.dispose();
    jumpCtrl.dispose();
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

              // Background Music Section
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Music',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_backgroundMusicUrlCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.music_note,
                                color: Colors.redAccent.shade200,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Music uploaded',
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBackgroundMusic == null
                                  ? 'No file selected'
                                  : _selectedBackgroundMusic!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickBackgroundMusic,
                            icon: Icon(Icons.folder_open, color: Colors.black),
                            label: Text('Choose Music'),
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
                          onPressed: _uploading ? null : _uploadBackgroundMusic,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade200,
                            foregroundColor: Colors.black,
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text('Upload Background Music'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pipe Passed Sound Section
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipe Passed Sound',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_pipePassedSoundUrlCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up,
                                color: Colors.redAccent.shade200,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sound uploaded',
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPipePassedSound == null
                                  ? 'No file selected'
                                  : _selectedPipePassedSound!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickPipePassedSound,
                            icon: Icon(Icons.folder_open, color: Colors.black),
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
                          onPressed:
                              (_uploading || _selectedPipePassedSound == null)
                              ? null
                              : _uploadPipePassedSound,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Upload Pipe Passed Sound'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Default Game Over Sound Section
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Game Over Sound',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This sound will be used for characters that don\'t have a custom game over sound.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 16),
                      if (_defaultGameOverSoundUrlCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up,
                                color: Colors.redAccent.shade200,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Default sound uploaded',
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDefaultGameOverSound == null
                                  ? 'No file selected'
                                  : _selectedDefaultGameOverSound!.name,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploading
                                ? null
                                : _pickDefaultGameOverSound,
                            icon: Icon(Icons.folder_open, color: Colors.black),
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
                          onPressed:
                              (_uploading ||
                                  _selectedDefaultGameOverSound == null)
                              ? null
                              : _uploadDefaultGameOverSound,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Upload Default Game Over Sound'),
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
                      // Preview of selected sprite
                      if (_editedCharacterSpriteBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preview (will be displayed as circular):',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.redAccent.shade200,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.memory(
                                      _editedCharacterSpriteBytes!,
                                      fit: BoxFit.fill,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
              Consumer<CharacterProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    );
                  }

                  if (provider.error != null) {
                    return Text('Error: ${provider.error}');
                  }

                  final characters = provider.characters;

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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue.shade400,
                                ),
                                onPressed: () => _editCharacter(character),
                                tooltip: 'Edit',
                              ),
                              IconButton(
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
                                        'Are you sure you want to delete ${character.name}? This will also delete associated media files.',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey[300],
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteCharacter(
                                              character.id,
                                              character.spriteUrl,
                                              character.gameOverSoundUrl,
                                            );
                                            setState(() {}); // Refresh the list
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
                                tooltip: 'Delete',
                              ),
                            ],
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
