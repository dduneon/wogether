import 'client.dart';

class CalendarApi {
  static Future<Map<String, dynamic>> getWorkoutCalendar({required int year, required int month}) async {
    final res = await dio.get('/api/me/workout-calendar', queryParameters: {'year': year, 'month': month});
    return Map<String, dynamic>.from(res.data);
  }
}
