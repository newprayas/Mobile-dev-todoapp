import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;

  ApiService(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
        ),
      );

  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<Map<String, dynamic>> authWithIdToken(String idToken) async {
    final resp = await _dio.post('/api/auth', data: {'id_token': idToken});
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchTodos() async {
    final resp = await _dio.get('/api/todos');
    return resp.data as List<dynamic>;
  }

  Future<dynamic> addTodo(String text, int hours, int minutes) async {
    final resp = await _dio.post(
      '/add',
      data: {
        'text': text,
        'duration_hours': hours,
        'duration_minutes': minutes,
      },
    );
    return resp.data;
  }

  Future<dynamic> deleteTodo(int id) async {
    final resp = await _dio.post('/delete', data: {'id': id});
    return resp.data;
  }

  Future<dynamic> toggleTodo(int id) async {
    final resp = await _dio.post('/toggle', data: {'id': id});
    return resp.data;
  }

  Future<dynamic> updateFocusTime(int id, int focusedTime) async {
    final resp = await _dio.post(
      '/update_focus_time',
      data: {'id': id, 'focused_time': focusedTime},
    );
    return resp.data;
  }
}
