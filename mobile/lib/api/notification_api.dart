import 'client.dart';

class NotificationApi {
  static Future<List> getNotifications() async {
    final res = await dio.get('/api/notifications');
    return res.data;
  }

  static Future<void> markAllRead() async {
    await dio.post('/api/notifications/read');
  }

  static Future<int> getUnreadCount() async {
    final res = await dio.get('/api/notifications/unread-count');
    return res.data['count'];
  }
}
