import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStore extends ChangeNotifier {
  static final AuthStore _instance = AuthStore._internal();
  factory AuthStore() => _instance;
  AuthStore._internal();

  final _storage = const FlutterSecureStorage();

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;

  Future<void> load() async {
    _token = await _storage.read(key: 'api_token');
    final userJson = await _storage.read(key: 'api_user');
    if (userJson != null) {
      _user = Map<String, dynamic>.from(jsonDecode(userJson));
    }
    notifyListeners();
  }

  Future<void> setToken(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    await _storage.write(key: 'api_token', value: token);
    await _storage.write(key: 'api_user', value: jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'api_token');
    await _storage.delete(key: 'api_user');
    notifyListeners();
  }
}
