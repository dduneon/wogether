import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/client.dart';

// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'wogether_default',
    'Wogether 알림',
    description: '운동 인증, 독촉, 목표 알림',
    importance: Importance.high,
  );

  static Future<void> init() async {
    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // 알림 권한 요청
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 로컬 알림 채널 생성 (Android)
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 로컬 알림 초기화
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 포그라운드 알림 표시 설정
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // 포그라운드 메시지 수신 → 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotif.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });

    // FCM 토큰 서버에 저장 (iOS는 APNS 토큰 준비까지 대기)
    String? token;
    if (Platform.isIOS) {
      for (var i = 0; i < 10; i++) {
        final apns = await _fcm.getAPNSToken();
        if (apns != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    // 토큰 갱신 시 재저장
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    try {
      await dio.post('/api/fcm-token', data: {'token': token});
    } catch (e) {
      // ignore: avoid_print
      print('[FCM] 토큰 저장 실패: $e');
    }
  }
}
