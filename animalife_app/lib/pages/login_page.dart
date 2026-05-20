import 'package:flutter/material.dart';
import '../services/animalife_api.dart';
import 'pet_select_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AnimalifeApi.sendOtp(email);
      setState(() { _codeSent = true; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _verify() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (email.isEmpty || code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AnimalifeApi.verifyOtp(email, code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PetSelectPage()),
      );
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🐾', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'AnimalLife Device',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Переводчик звуков питомца',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white54),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Код из письма',
                    labelStyle: const TextStyle(color: Colors.white54),
                    counterStyle: const TextStyle(color: Colors.transparent),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : ElevatedButton(
                      onPressed: _codeSent ? _verify : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _codeSent ? 'Войти' : 'Получить код',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () => setState(() { _codeSent = false; _codeCtrl.clear(); _error = null; }),
                  child: const Text('Изменить email', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }
}
