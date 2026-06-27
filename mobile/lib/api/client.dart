import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://wogether.dduneon.com');

final _storage = FlutterSecureStorage();

Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // 요청마다 토큰 자동 삽입
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'api_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      print('[API ERROR] ${error.requestOptions.method} ${error.requestOptions.path} → ${error.response?.statusCode} ${error.message}');
      handler.next(error);
    },
  ));

  return dio;
}

final dio = createDio();

/// 서버에서 받은 이미지 URL의 호스트를 현재 baseUrl 기준으로 보정
String fixImageUrl(String url) {
  return url
      .replaceAll('localhost', Uri.parse(baseUrl).host)
      .replaceAll('10.0.2.2', Uri.parse(baseUrl).host);
}
