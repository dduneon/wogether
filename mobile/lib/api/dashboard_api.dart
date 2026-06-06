import 'client.dart';

class DashboardApi {
  static Future<Map<String, dynamic>> getDashboard() async {
    final res = await dio.get('/api/dashboard');
    return Map<String, dynamic>.from(res.data);
  }
}
