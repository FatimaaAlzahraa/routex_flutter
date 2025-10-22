import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Session {
  static const _kToken = 'rtx_token';
  static const _secure = FlutterSecureStorage();

  static Future<void> saveToken(String token) =>
      _secure.write(key: _kToken, value: token);

  static Future<String?> get token async => _secure.read(key: _kToken);

  static Future<void> clear() => _secure.delete(key: _kToken);
}
