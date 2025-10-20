// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isRegister = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Giriş / Kayıt'),
          Expanded(
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 56, color: cs.primary),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCtl,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passCtl,
                          decoration: const InputDecoration(
                            labelText: 'Parola',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _submit,
                                icon: Icon(
                                  _isRegister
                                      ? Icons.app_registration
                                      : Icons.login,
                                ),
                                label: Text(
                                  _isRegister ? 'Kayıt Ol' : 'Giriş Yap',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed:
                                  () => setState(() {
                                    _isRegister = !_isRegister;
                                    _error = null;
                                  }),
                              child: Text(
                                _isRegister
                                    ? 'Zaten hesabım var'
                                    : 'Hesap oluştur',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Tüm alanları doldurun.');
      return;
    }
    if (_isRegister) {
      final ok = await _auth.register(email, pass);
      if (!ok) {
        setState(() => _error = 'Kayıt yapılamadı (zaten kayıtlı olabilir).');
        return;
      }
    }
    final logged = await _auth.login(email, pass);
    if (!logged) {
      setState(() => _error = 'Giriş başarısız.');
      return;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
}
