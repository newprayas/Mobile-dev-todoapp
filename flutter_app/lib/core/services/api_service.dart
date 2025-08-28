import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// For local development the Dart backend accepts a simple header 'x-user-id'
// to simulate a logged-in user (the original Flask app used OAuth). When the
// ApiService is constructed with a local baseUrl we add that header so the
// client can talk to the Dart server without an OAuth flow.

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

  ApiService(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
        ),
      ) {
    final lower = baseUrl.toLowerCase();
    if (lower.contains('127.0.0.1') ||
        lower.contains('localhost') ||
        lower.contains('10.0.2.2')) {
      // default dev user id
      _dio.options.headers['x-user-id'] = 'dev';
    }
  }

  /// Sets the authentication token for API requests.
  ///
  /// Configures the Authorization header for authenticated requests.
  /// Pass null to remove authentication.
  ///
  /// Parameters:
  /// - [token]: JWT token or null to remove authentication
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Authenticates with Google ID token and returns user data.
  ///
  /// Parameters:
  /// - [idToken]: Google OAuth ID token
  ///
  /// Returns: Map containing user authentication data
  Future<Map<String, dynamic>> authWithIdToken(String idToken) async {
    final resp = await _dio.post('/api/auth', data: {'id_token': idToken});
    return resp.data as Map<String, dynamic>;
  }

  /// Fetches all todos for the authenticated user.
  ///
  /// Returns: List of todo objects as dynamic maps
  Future<List<dynamic>> fetchTodos() async {
    final resp = await _withRetry(() => _dio.get('/api/todos'));
    return resp.data as List<dynamic>;
  }

  /// Creates a new todo with specified duration.
  ///
  /// Parameters:
  /// - [text]: Todo description text
  /// - [hours]: Planned duration hours (0-23)
  /// - [minutes]: Planned duration minutes (0-59)
  ///
  /// Returns: Server response containing the created todo data
  Future<dynamic> addTodo(String text, int hours, int minutes) async {
    final resp = await _withRetry(
      () => _dio.post(
        '/add',
        data: {
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

  /// Deletes a todo by ID.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to delete
  ///
  /// Returns: Server response confirming deletion
  Future<dynamic> deleteTodo(int id) async {
    final resp = await _withRetry(() => _dio.post('/delete', data: {'id': id}));
    return resp.data;
  }

  /// Updates todo properties.
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
    final Map<String, dynamic> data = {'id': id};
    if (text != null) data['text'] = text;
    if (hours != null) data['duration_hours'] = hours;
    if (minutes != null) data['duration_minutes'] = minutes;
    final resp = await _dio.post('/update', data: data);
    return resp.data;
  }

  Future<dynamic> toggleTodo(int id) async {
    final resp = await _withRetry(() => _dio.post('/toggle', data: {'id': id}));
    return resp.data;
  }

  Future<dynamic> toggleTodoWithOverdue(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    final payload = {
      'id': id,
      'was_overdue': wasOverdue ? 1 : 0,
      'overdue_time': overdueTime,
    };
    final resp = await _withRetry(() => _dio.post('/toggle', data: payload));
    return resp.data;
  }

  /// Updates the focused time for a specific todo.
  ///
  /// Critical for progress tracking and Pomodoro timer integration.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to update
  /// - [focusedTime]: Total focused time in seconds
  ///
  /// Returns: Server response confirming the update
  Future<dynamic> updateFocusTime(int id, int focusedTime) async {
    final resp = await _withRetry(
      () => _dio.post(
        '/update_focus_time',
        data: {'id': id, 'focused_time': focusedTime},
      ),
    );
    return resp.data;
  }

  // Generic retry wrapper to soften initial startup race where the backend
  // server process might not yet be listening and Dio throws a connection
  // error (SocketException: Connection refused). Only retries for connection
  // level errors, not for HTTP status codes.
  Future<Response<dynamic>> _withRetry(
    Future<Response<dynamic>> Function() fn,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on DioException catch (e) {
        final isConnError =
            e.type == DioExceptionType.connectionError ||
            e.error is Error ||
            (e.message?.toLowerCase().contains('connection refused') ?? false);
        if (!isConnError || attempt >= _maxRetries - 1) {
          if (kDebugMode) {
            debugPrint(
              'ApiService retry aborted (attempt ${attempt + 1}/$_maxRetries). Error: $e',
            );
          }
          rethrow;
        }
        attempt++;
        if (kDebugMode) {
          debugPrint(
            'ApiService transient connection error, retrying ($attempt/$_maxRetries) in ${_retryDelay.inMilliseconds}ms ...',
          );
        }
        await Future.delayed(_retryDelay);
      }
    }
  }
}
