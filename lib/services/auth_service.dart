import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _userKey = 'local_user_email';
  final _passKey = 'local_user_password_hash';

  Future<bool> register(String email, String password) async {
    // Basit check: kayıtlı mı?
    final existing = await _storage.read(key: _userKey);
    if (existing != null) return false;

    final hash = _simpleHash(password);
    await _storage.write(key: _userKey, value: email);
    await _storage.write(key: _passKey, value: hash);
    return true;
  }

  Future<bool> login(String email, String password) async {
    final storedEmail = await _storage.read(key: _userKey);
    final storedHash = await _storage.read(key: _passKey);
    if (storedEmail == null || storedHash == null) return false;
    if (storedEmail != email) return false;
    return storedHash == _simpleHash(password);
  }

  Future<void> logout() async {}

  Future<String?> getCurrentUser() async {
    return await _storage.read(key: _userKey);
  }

  String _simpleHash(String s) {
    var v = 0;
    for (var i = 0; i < s.length; i++) {
      v = (v * 31 + s.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return v.toString();
  }
}
