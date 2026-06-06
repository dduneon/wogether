import 'client.dart';

class GoalApi {
  static Future<List> getGoals(int crewId) async {
    final res = await dio.get('/api/crews/$crewId/goals');
    return res.data;
  }

  static Future<Map<String, dynamic>> createGoal({
    required int crewId,
    required String title,
    required String category,
    required int frequencyPerWeek,
    String? description,
  }) async {
    final res = await dio.post('/api/crews/$crewId/goals', data: {
      'title': title,
      'category': category,
      'frequency_per_week': frequencyPerWeek,
      if (description != null) 'description': description,
    });
    return res.data;
  }

  static Future<void> approveGoal(int goalId) async {
    await dio.post('/api/goals/$goalId/approve');
  }

  static Future<void> deleteGoal(int goalId) async {
    await dio.delete('/api/goals/$goalId');
  }
}
