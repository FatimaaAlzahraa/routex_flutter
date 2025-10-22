//auth_service.dart
import '../../core/api_client.dart';
import '../../core/session.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<void> login({required String phone, required String password}) async {
    final data = await _api.postJson(ApiClient.loginPath, {
      'phone': phone,
      'password': password,
    });

    final token = _extractToken(data);
    if (token == null || token.isEmpty) {
      throw Exception('Token not found in response');
    }
    await Session.saveToken(token);
  }

  Future<WhoIs> whois() async {
    final data = await _api.getJson(ApiClient.whoisPath, auth: true);

    // مرونة في أماكن الحقول (حسب الـ API عندك)
    final user = (data['user'] is Map<String, dynamic>) ? data['user'] as Map<String, dynamic> : null;

    final name  = (data['name'] ?? data['username'] ?? user?['name'] ?? '').toString();
    final role  = (data['role'] ?? user?['role'] ?? '').toString();
    final phone = (data['phone'] ?? user?['phone'] ?? '').toString();

    return WhoIs(name: name, role: role, phone: phone);
  }

  String? _extractToken(Map<String, dynamic> json) {
    String? from(Map<String, dynamic> m) {
      for (final k in const [
        'access',
        'token',
        'access_token',
        'jwt',
        'auth_token',
        'api_token',
      ]) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
      final data = m['data'];
      if (data is Map<String, dynamic>) return from(data);
      final result = m['result'];
      if (result is Map<String, dynamic>) return from(result);
      return null;
    }
    return from(json);
  }
}

class WhoIs {
  final String name;
  final String role;
  final String phone; // ← جديد

  const WhoIs({
    required this.name,
    required this.role,
    this.phone = '',
  });
}
