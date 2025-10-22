// lib/core/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'session.dart';

class ApiClient {
  static const String baseUrl = 'https://6be6065a55bc.ngrok-free.app/';

  // مسارات شائعة
  static const String loginPath = 'api/login';
  static const String whoisPath = 'api/whois';

  final Uri _base = Uri.parse(baseUrl);

  // ----------------------------------
  // مساعد صغير لفك JSON بأمان
  // ----------------------------------
  static Map<String, dynamic>? tryDecode(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) return d;
      return {'data': d};
    } catch (_) {
      return null;
    }
  }

  // ============ JSON ============

  Future<Map<String, dynamic>> postJson(
      String path,
      Map<String, dynamic> body, {
        bool auth = false,
      }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await Session.token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .post(_base.resolve(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<dynamic> getJson(
      String path, {
        bool auth = false,
      }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (auth) {
      final t = await Session.token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .get(_base.resolve(path), headers: headers)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> patchJson(
      String path,
      Map<String, dynamic> body, {
        bool auth = false,
      }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await Session.token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .patch(_base.resolve(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<void> delete(
      String path, {
        bool auth = false,
      }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (auth) {
      final t = await Session.token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }

    final res = await http
        .delete(_base.resolve(path), headers: headers)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw ApiException(res.statusCode, res.body);
  }

  // ============ MULTIPART (صور/ملفات) ============

  /// POST Multipart (مثالي لإنشاء منتج مع صورة)
  Future<Map<String, dynamic>> postMultipart(
      String path, {
        Map<String, String>? fields,
        Map<String, File>? files,
        bool auth = false,
      }) async {
    final uri = _base.resolve(path);
    final req = http.MultipartRequest('POST', uri);

    if (auth) {
      final t = await Session.token;
      if (t != null) req.headers['Authorization'] = 'Bearer $t';
    }
    if (fields != null) req.fields.addAll(fields);

    if (files != null) {
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
      }
    }

    final res = await req.send().timeout(const Duration(seconds: 30));
    final body = await res.stream.bytesToString();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, body);
  }

  /// PATCH Multipart (تعديل مع إمكانية استبدال الصورة)
  Future<Map<String, dynamic>> patchMultipart(
      String path, {
        Map<String, String>? fields,
        Map<String, File>? files,
        bool auth = false,
      }) async {
    final uri = _base.resolve(path);
    final req = http.MultipartRequest('PATCH', uri);

    if (auth) {
      final t = await Session.token;
      if (t != null) req.headers['Authorization'] = 'Bearer $t';
    }
    if (fields != null) req.fields.addAll(fields);

    if (files != null) {
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
      }
    }

    final res = await req.send().timeout(const Duration(seconds: 30));
    final body = await res.stream.bytesToString();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map<String, dynamic>);
    }
    throw ApiException(res.statusCode, body);
  }
}

class ApiException implements Exception {
  final int code;
  final String body;
  ApiException(this.code, this.body);
  @override
  String toString() => 'ApiException($code): $body';
}
