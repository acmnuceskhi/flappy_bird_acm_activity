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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter password')),
      );
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
          builder: (_) => AdminPanelPage(
            gameId: widget.gameId,
            settings: widget.settings,
          ),
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
      appBar: AppBar(
        title: const Text('Admin Access'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Enter admin password to access',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
