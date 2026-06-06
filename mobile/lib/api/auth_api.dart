import 'client.dart';

class AuthApi {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await dio.post('/api/login', data: {
      'username': username,
      'password': password,
    });
    return res.data;
  }

  static Future<Map<String, dynamic>> signup(
      String username, String password, String nickname) async {
    final res = await dio.post('/api/signup', data: {
      'username': username,
      'password': password,
      'nickname': nickname,
    });
    return res.data;
  }

  static Future<Map<String, dynamic>> me() async {
    final res = await dio.get('/api/me');
    return res.data;
  }
}
