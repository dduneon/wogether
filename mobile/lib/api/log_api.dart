import 'package:dio/dio.dart';
import 'client.dart';

class LogApi {
  static Future<List> getLogs(int crewId) async {
    final res = await dio.get('/api/crews/$crewId/logs');
    return res.data;
  }

  static Future<Map<String, dynamic>> createLog({
    required int crewId,
    required List<String> photoPaths,
    String? caption,
    String? workoutType,
    int? goalId,
  }) async {
    final formData = FormData();
    for (final path in photoPaths) {
      formData.files.add(MapEntry('photo', await MultipartFile.fromFile(path)));
    }
    if (caption != null) formData.fields.add(MapEntry('caption', caption));
    if (workoutType != null) formData.fields.add(MapEntry('workout_type', workoutType));
    if (goalId != null) formData.fields.add(MapEntry('goal_id', goalId.toString()));

    final res = await dio.post(
      '/api/crews/$crewId/logs',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return res.data;
  }

  static Future<void> deleteLog(int logId) async {
    await dio.delete('/api/logs/$logId');
  }

  static Future<Map<String, dynamic>> toggleLike(int logId) async {
    final res = await dio.post('/api/logs/$logId/like');
    return res.data;
  }
}
