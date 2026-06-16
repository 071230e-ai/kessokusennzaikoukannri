// API クライアント。Pages Functions (/api/*) を呼び出す。
//
// Flutter Web で同一オリジンのアプリ内から fetch するため、ベースURLは空文字
// （相対パス）でよい。ローカルテストで別ホストから叩く場合は kBaseUrl を切替。
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? body;
  ApiException(this.status, this.message, [this.body]);
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  static const String baseUrl = ''; // 同一オリジン

  /// JSON GET
  static Future<Map<String, dynamic>> getJson(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: const {'Accept': 'application/json'},
    );
    return _handle(res);
  }

  /// JSON POST
  static Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  /// DELETE
  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: const {'Accept': 'application/json'},
    );
    return _handle(res);
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? parsed;
    if (text.isNotEmpty) {
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        parsed = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parsed ?? <String, dynamic>{};
    }
    final msg = (parsed?['error'] as String?) ?? 'HTTP ${res.statusCode}';
    throw ApiException(res.statusCode, msg, parsed);
  }
}
