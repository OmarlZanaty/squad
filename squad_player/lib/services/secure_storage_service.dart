import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kToken = 'auth_token';
  static const String _kBiometricEnabled = 'biometric_enabled';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _kToken, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _kToken);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _kToken);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _kBiometricEnabled, value: enabled ? '1' : '0');

    // DEBUG (remove later)
    final v = await _storage.read(key: _kBiometricEnabled);
    // ignore: avoid_print
    print('SECURE: biometric_enabled saved = $v');
  }

  static Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _kBiometricEnabled);

    // DEBUG (remove later)
    // ignore: avoid_print
    print('SECURE: biometric_enabled read = $v');

    return v == '1';
  }

  // Optional helper for debugging
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
