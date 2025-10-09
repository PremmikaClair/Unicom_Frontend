import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal auth helper for the mobile app.
/// - Stores JWT access token in SharedPreferences
/// - Builds Authorization headers for API calls
class AuthService {
  // Define both API URLs
  final String base1 = const String.fromEnvironment(
    'API_BASE_URL_1',
    defaultValue: 'https://frontend-23os.onrender.com',
  );

  final String base2 = const String.fromEnvironment(
    'API_BASE_URL_2',
    defaultValue:
        'https://backend-gezu.onrender.com', // Replace with your second API
  );

  // Add a selector to choose which API to use
  bool _useSecondAPI = false;

  String get apiBase {
    final base = _useSecondAPI ? base2 : base1;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$b/api';
  }

  // Method to switch between APIs
  void useSecondAPI(bool useSecond) {
    _useSecondAPI = useSecond;
  }

  String? _token;
  bool _inited = false;

  String? get token => _token;
  bool get isAuthed => (_token != null && _token!.isNotEmpty);

  Future<void> init() async {
    if (_inited) return;
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('access_token');
    _inited = true;
  }

  Future<void> _saveToken(String? tok) async {
    _token = tok;
    final sp = await SharedPreferences.getInstance();
    if (tok == null || tok.isEmpty) {
      await sp.remove('access_token');
    } else {
      await sp.setString('access_token', tok);
    }
  }

  Uri apiUri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final u = Uri.parse('$apiBase$p');
    if (query == null) return u;
    return u.replace(
      queryParameters: {
        for (final e in query.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      },
    );
  }

  Map<String, String> headers({Map<String, String>? extra}) {
    return {
      'Accept': 'application/json',
      if (extra != null) ...extra,
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };
  }

  Future<void> logout() async {
    await _saveToken(null);
  }

  /// POST /api/auth/login { email, password } -> { access_token }
  Future<void> login(String email, String password) async {
    final uri = apiUri('/auth/login');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tok = (data['access_token'] ?? data['accessToken'])?.toString();
    if (tok == null || tok.isEmpty) {
      throw Exception('No access token');
    }
    await _saveToken(tok);
  }

  /// GET /api/auth/me (verifies token and returns claims)
  Future<Map<String, dynamic>> me() async {
    final uri = apiUri('/auth/me');
    final res = await http
        .get(uri, headers: headers())
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Auth check failed: ${res.statusCode} ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty) return <String, dynamic>{};
    final data = jsonDecode(body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
