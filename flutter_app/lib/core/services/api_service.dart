import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_logger.dart';

/// HTTP API client for todo management with automatic retry logic.
///
/// Provides a complete REST API interface for todo CRUD operations,
/// authentication, and focus time tracking. Includes automatic retry
/// logic for connection errors and local development authentication.
class ApiService {
  final Dio _dio;
  // configurable retry attempts for transient connection errors (e.g. server
  // not up yet). Keep small to avoid long UI stalls.
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(milliseconds: 500);

  final String _devUserId = 'dev'; // Add this line to store the dev user ID

  ApiService(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
        ),
      ) {
    // If the base URL points to a local development server, always add
    // the dev user id header so mock authentication works even in release
    // builds that use a local backend via adb reverse or emulator host.
    final String lowerBaseUrl = baseUrl.toLowerCase();
    if (lowerBaseUrl.contains('127.0.0.1') ||
        lowerBaseUrl.contains('localhost') ||
        lowerBaseUrl.contains('10.0.2.2')) {
      _dio.options.headers['x-user-id'] = _devUserId;
      debugLog('ApiService', 'Set x-user-id header for local dev: $_devUserId');
    }
  }

  /// Development user id automatically injected for local backends.
  String get devUserId => _devUserId; // Add this getter

  /// Sets or clears the Authorization bearer token.
  /// Passing null removes the header.
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Authenticate using a Google ID token.
  /// Returns a map containing auth token and user data.
  ///
  /// Parameters:
  /// - [idToken]: Google OAuth ID token
  ///
  /// Returns: Map containing user authentication data
  Future<Map<String, dynamic>> authWithIdToken(String idToken) async {
    final Response<dynamic> resp = await _dio.post('/api/auth', data: {'id_token': idToken});
    return resp.data as Map<String, dynamic>;
  }

  /// Fetch all todos for the current user.
  ///
  /// Returns: List of todo objects as dynamic maps
  Future<List<dynamic>> fetchTodos() async {
    final Response<dynamic> resp = await _withRetry(() => _dio.get('/api/todos'));
    return resp.data as List<dynamic>;
  }

  /// Create a new todo with provided duration components.
  ///
  /// Parameters:
  /// - [text]: Todo description text
  /// - [hours]: Planned duration hours (0-23)
  /// - [minutes]: Planned duration minutes (0-59)
  ///
  /// Returns: Server response containing the created todo data
  Future<dynamic> addTodo(String text, int hours, int minutes) async {
    final Response<dynamic> resp = await _withRetry(
      () => _dio.post(
        '/add',
        data: <String, dynamic>{
          'text': text,
          'duration_hours': hours,
          'duration_minutes': minutes,
        },
      ),
    );
    // log server response for debugging duplicate issues
    try {
      if (kDebugMode) debugPrint('ApiService.addTodo response: ${resp.data}');
    } catch (_) {}
    return resp.data;
  }

  /// Delete todo by id.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to delete
  ///
  /// Returns: Server response confirming deletion
  Future<dynamic> deleteTodo(int id) async {
    final Response<dynamic> resp = await _withRetry(() => _dio.post('/delete', data: {'id': id}));
    return resp.data;
  }

  /// Partially update fields on a todo.
  ///
  /// Allows partial updates of todo text and/or duration.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to update
  /// - [text]: New description text (optional)
  /// - [hours]: New planned duration hours (optional)
  /// - [minutes]: New planned duration minutes (optional)
  ///
  /// Returns: Server response containing updated todo data
  Future<dynamic> updateTodo(
    int id, {
    String? text,
    int? hours,
    int? minutes,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{'id': id};
    if (text != null) data['text'] = text;
    if (hours != null) data['duration_hours'] = hours;
    if (minutes != null) data['duration_minutes'] = minutes;
    final Response<dynamic> resp = await _dio.post('/update', data: data);
    return resp.data;
  }

  /// Toggle completion state of a todo.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to toggle
  ///
  /// Returns: Server response containing the toggled todo data
  Future<dynamic> toggleTodo(int id) async {
    final Response<dynamic> resp = await _withRetry(() => _dio.post('/toggle', data: {'id': id}));
    return resp.data;
  }

  /// Toggle completion with overdue metadata.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to toggle
  /// - [wasOverdue]: Previous overdue state (optional)
  /// - [overdueTime]: Overdue time in seconds (optional)
  ///
  /// Returns: Server response containing the toggled todo data
  Future<dynamic> toggleTodoWithOverdue(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': id,
      'was_overdue': wasOverdue ? 1 : 0,
      'overdue_time': overdueTime,
    };
    final Response<dynamic> resp = await _withRetry(() => _dio.post('/toggle', data: payload));
    return resp.data;
  }

  /// Persist focused time progress for a todo in seconds.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to update
  /// - [focusedTime]: Total focused time in seconds
  ///
  /// Returns: Server response confirming the update
  Future<dynamic> updateFocusTime(int id, int focusedTime) async {
    final Response<dynamic> resp = await _withRetry(
      () => _dio.post(
        '/update_focus_time',
        data: <String, dynamic>{'id': id, 'focused_time': focusedTime},
      ),
    );
    return resp.data;
  }

  /// Retry wrapper for transient connection failures.
  ///
  /// Parameters:
  /// - [fn]: A function that returns a Future<Response<dynamic>> to execute with retries
  ///
  /// Returns: The response from the successful function execution
  Future<Response<dynamic>> _withRetry(
    Future<Response<dynamic>> Function() fn,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on DioException catch (e) {
        final bool isConnError =
            e.type == DioExceptionType.connectionError ||
            e.error is Error ||
            (e.message?.toLowerCase().contains('connection refused') ?? false);

        // ALWAYS log detailed errors for tester APK debugging.
        if (e.type == DioExceptionType.badResponse) {
          debugLog(
            'ApiService',
            'API Error: Status ${e.response?.statusCode}, Data: ${e.response?.data}, Message: ${e.message}',
          );
        } else {
          debugLog(
            'ApiService',
            'Network Error: Type ${e.type}, Message: ${e.message}, Error: ${e.error}, Stack: ${e.stackTrace}',
          );
        }

        if (!isConnError || attempt >= _maxRetries - 1) {
          // If not a transient connection error, or max retries reached, rethrow.
          rethrow; // Re-throw the original exception to propagate.
        }
        attempt++;
        // Log retry attempts with basic info, still useful for debugging.
        debugLog(
          'ApiService',
          'Transient connection error, retrying ($attempt/$_maxRetries) in ${_retryDelay.inMilliseconds}ms ...',
        );
        await Future.delayed(_retryDelay);
      }
    }
  }
}
