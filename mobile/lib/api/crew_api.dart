import 'client.dart';

class CrewApi {
  static Future<List> getCrews() async {
    final res = await dio.get('/api/crews');
    return res.data;
  }

  static Future<Map<String, dynamic>> createCrew(String name, String? description) async {
    final res = await dio.post('/api/crews', data: {
      'name': name,
      if (description != null) 'description': description,
    });
    return res.data;
  }

  static Future<Map<String, dynamic>> getCrew(int crewId) async {
    final res = await dio.get('/api/crews/$crewId');
    return res.data;
  }

  static Future<Map<String, dynamic>> joinCrew(String code) async {
    final res = await dio.post('/api/crews/join', data: {'code': code});
    return res.data;
  }

  static Future<void> leaveCrew(int crewId) async {
    await dio.post('/api/crews/$crewId/leave');
  }

  static Future<void> nudge(int crewId, int targetUserId) async {
    await dio.post('/api/crews/$crewId/nudge/$targetUserId');
  }
}
