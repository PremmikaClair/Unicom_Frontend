import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal auth helper for the mobile app.
/// - Stores JWT access token in SharedPreferences
/// - Builds Authorization headers for API calls
class AuthService {
  AuthService._();
  static final AuthService I = AuthService._();

  // Base like http://127.0.0.1:8000 (main-webbase)
  final String base = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  String? _token;
  bool _inited = false;

  String get apiBase {
    var b = base;
    // On Android emulator, localhost refers to the emulator. Use 10.0.2.2 to reach host.
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          if (b.contains('127.0.0.1')) b = b.replaceAll('127.0.0.1', '10.0.2.2');
          if (b.contains('localhost')) b = b.replaceAll('localhost', '10.0.2.2');
        }
      } catch (_) {
        // Platform not available (some targets); ignore
      }
    }
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

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
    return u.replace(queryParameters: {
      for (final e in query.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    });
  }

  Map<String, String> headers({Map<String, String>? extra}) {
    return {
      'Accept': 'application/json',
      if (extra != null) ...extra,
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Future<void> logout() async {
    await _saveToken(null);
  }

  // ---- Registration (Sign Up) ----
  // Payload mirrors backend models.RegisterRequest JSON schema
  // firstname, lastname, email, password are the common required fields
  // others are optional
  Future<Map<String, dynamic>> register(RegisterPayload p) async {
    final uri = apiUri('/register');
    final email = p.email.trim();
    final map = <String, dynamic>{
      // lowercase keys (our local backend)
      'firstname': p.firstname.trim(),
      'lastname': p.lastname.trim(),
      if (p.thaiprefix != null && p.thaiprefix!.isNotEmpty) 'thaiprefix': p.thaiprefix,
      if (p.gender != null && p.gender!.isNotEmpty) 'gender': p.gender,
      if (p.typePerson != null && p.typePerson!.isNotEmpty) 'type_person': p.typePerson,
      if (p.studentId != null && p.studentId!.isNotEmpty) 'student_id': p.studentId,
      if (p.advisorId != null && p.advisorId!.isNotEmpty) 'advisor_id': p.advisorId,
      'email': email,
      'password': p.password,
      if (p.organizePath != null && p.organizePath!.isNotEmpty) 'organize_path': p.organizePath,

      // TitleCase keys (remote backend examples)
      'FirstName': p.firstname.trim(),
      'LastName': p.lastname.trim(),
      if (p.thaiprefix != null && p.thaiprefix!.isNotEmpty) 'ThaiPrefix': p.thaiprefix,
      if (p.gender != null && p.gender!.isNotEmpty) 'Gender': p.gender,
      if (p.typePerson != null && p.typePerson!.isNotEmpty) 'TypePerson': p.typePerson,
      if (p.studentId != null && p.studentId!.isNotEmpty) 'StudentID': p.studentId,
      if (p.advisorId != null && p.advisorId!.isNotEmpty) 'AdvisorID': p.advisorId,
      'Email': email,
      'Password': p.password,
      if (p.organizePath != null && p.organizePath!.isNotEmpty) 'OrgPath': p.organizePath,
      if (p.organizePath != null && p.organizePath!.isNotEmpty) 'OrganizePath': p.organizePath,
    };
    final body = jsonEncode(map);

    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Register failed: ${res.statusCode} ${res.body}');
    }
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /login { email, password } -> { accessToken }
  Future<void> login(String email, String password) async {
    final uri = apiUri('/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tok = (data['accessToken'] ?? data['access_token'])?.toString();
    if (tok == null || tok.isEmpty) {
      throw Exception('No access token');
    }
    await _saveToken(tok);
  }

  /// GET /users/myprofile (verifies token and returns profile)
  Future<Map<String, dynamic>> me() async {
    final uri = apiUri('/users/myprofile');
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

  /// POST /verify-otp { email, otp }
  Future<void> verifyOtp({required String email, required String otp}) async {
    final uri = apiUri('/verify-otp');
    final res = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
        )
        .timeout(const Duration(seconds: 12));

    // Treat 200 OK and 201 Created as success
    if (res.statusCode != 200 && res.statusCode != 201) {
      // Try to surface backend 'error' field when possible
      try {
        final body = jsonDecode(res.body);
        final msg = body is Map && body['error'] != null ? body['error'].toString() : res.body;
        throw Exception('Verify failed: ${res.statusCode} $msg');
      } catch (_) {
        throw Exception('Verify failed: ${res.statusCode} ${res.body}');
      }
    }
  }
}
