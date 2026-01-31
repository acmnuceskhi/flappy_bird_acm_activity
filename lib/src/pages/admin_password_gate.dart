import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import 'admin_panel_page.dart';

/// Password gate for admin panel
/// Requires hardcoded password to access character/background management
class AdminPasswordGate extends StatefulWidget {
  final String gameId;
  final GameSettings settings;

  const AdminPasswordGate({
    super.key,
    required this.gameId,
    required this.settings,
  });

  @override
  State<AdminPasswordGate> createState() => _AdminPasswordGateState();
}

class _AdminPasswordGateState extends State<AdminPasswordGate> {
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  static const String _correctPassword = 'reallygoodpassword';

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;

    if (password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter password')));
      return;
    }

    setState(() => _loading = true);

    // Simulate a small delay for UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    if (password == _correctPassword) {
      // Password correct - navigate to admin panel
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              AdminPanelPage(gameId: widget.gameId, settings: widget.settings),
        ),
      );
    } else {
      // Password incorrect
      setState(() => _loading = false);
      _passwordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Admin Access',
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
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.12,
            ),
            child: Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 64,
                      color: Colors.redAccent.shade200,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter admin password to access',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[100]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade800),
                        ),
                        labelStyle: TextStyle(color: Colors.grey[300]),
                      ),
                      style: TextStyle(color: Colors.grey[100]),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade200,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
