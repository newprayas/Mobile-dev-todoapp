// lib/core/services/mock_api_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ...existing imports
import '../utils/debug_logger.dart'; // Import debugLog
import 'api_service.dart'; // Import the real ApiService to conform to its interface

/// Mock API service for backward compatibility during transition to local database
/// or for development without a running backend.
/// Provides stub implementations that do nothing or return empty/default results,
/// mimicking the [ApiService] interface.
class MockApiService extends ApiService {
  // IMPORTANT: extend ApiService so it can be used interchangeably
  String _devUserId = 'dev';

  @override
  String get devUserId => _devUserId;

  // Call super to initialize Dio but then we override network methods for mocking
  MockApiService(String baseUrl) : super(baseUrl) {
    debugLog(
      'MockApiService',
      'Initialized MockApiService with baseUrl: $baseUrl',
    );
    if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost')) {
      _devUserId = 'dev';
    }
  }

  // Mimic ApiService methods
  @override // Override from ApiService
  Future<List<dynamic>> fetchTodos() async {
    debugLog('MockApiService', 'Mock fetchTodos called. Returning empty list.');
    return Future.value([]);
  }

  @override // Override from ApiService
  Future<Map<String, dynamic>> addTodo(
    String text,
    int hours,
    int minutes,
  ) async {
    debugLog(
      'MockApiService',
      'Mock addTodo called for: $text. Returning dummy data.',
    );
    // Simulate a successful add for optimistic updates
    return Future.value({
      'id': DateTime.now().millisecondsSinceEpoch, // Unique ID
      'user_id': _devUserId,
      'text': text,
      'completed': 0,
      'duration_hours': hours,
      'duration_minutes': minutes,
      'focused_time': 0,
      'was_overdue': 0,
      'overdue_time': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override // Override from ApiService
  Future<dynamic> deleteTodo(int id) async {
    debugLog('MockApiService', 'Mock deleteTodo called for ID: $id');
    return Future.value({'result': 'success'});
  }

  @override // Override from ApiService
  Future<dynamic> updateTodo(
    int id, {
    String? text,
    int? hours,
    int? minutes,
  }) async {
    debugLog('MockApiService', 'Mock updateTodo called for ID: $id');
    return Future.value({'result': 'success'});
  }

  @override // Override from ApiService
  Future<dynamic> toggleTodoWithOverdue(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    debugLog('MockApiService', 'Mock toggleTodoWithOverdue called for ID: $id');
    return Future.value({'result': 'success'});
  }

  @override
  Future<dynamic> toggleTodo(int id) async {
    debugLog('MockApiService', 'Mock toggleTodo called for ID: $id');
    return Future.value({'result': 'success'});
  }

  @override // Override from ApiService
  Future<dynamic> updateFocusTime(int id, int focusedTime) async {
    debugLog(
      'MockApiService',
      'Mock updateFocusTime called for ID: $id, focusedTime: $focusedTime',
    );
    return Future.value({'result': 'success'});
  }

  @override // Override from ApiService
  Future<Map<String, dynamic>> authWithIdToken(String idToken) async {
    debugLog('MockApiService', 'Mock authWithIdToken called.');
    return Future.value({
      'token': 'mock_server_token',
      'user': {
        'id': 'mock_user',
        'email': 'mock@example.com',
        'name': 'Mock User',
      },
    });
  }

  @override // Override from ApiService
  void setAuthToken(String? token) {
    debugLog(
      'MockApiService',
      'Mock setAuthToken called with token: ${token?.substring(0, 5)}...',
    );
  }
}

/// Provider for the *actual* [ApiService] when running with a backend.
/// For local development, this is overridden with [MockApiService].
final apiServiceProvider = Provider<ApiService>((ref) {
  // This provider should normally return the real ApiService.
  // It is *overridden* in main.dart to provide MockApiService for local dev.
  throw UnimplementedError(
    'apiServiceProvider must be overridden in main.dart '
    'with either ApiService or MockApiService depending on the environment.',
  );
});
