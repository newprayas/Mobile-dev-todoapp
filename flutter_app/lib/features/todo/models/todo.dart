// lib/features/todo/models/todo.dart
class Todo {
  final int id;
  final String userId;
  final String text;
  final bool completed;
  final int durationHours;
  final int durationMinutes;
  final int focusedTime;
  final int wasOverdue;
  final int overdueTime;
  final DateTime createdAt; // Add createdAt to the Todo model

  Todo({
    required this.id,
    required this.userId,
    required this.text,
    required this.completed,
    required this.durationHours,
    required this.durationMinutes,
    required this.focusedTime,
    required this.wasOverdue,
    required this.overdueTime,
    required this.createdAt, // Must be provided now
  });

  // Removed fromJson - now handled by AppDatabase's mapping or ApiService directly
  // Removed toJson - now handled by ApiService directly if needed for upload

  Todo copyWith({
    int? id,
    String? userId,
    String? text,
    bool? completed,
    int? durationHours,
    int? durationMinutes,
    int? focusedTime,
    int? wasOverdue,
    int? overdueTime,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      durationHours: durationHours ?? this.durationHours,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      focusedTime: focusedTime ?? this.focusedTime,
      wasOverdue: wasOverdue ?? this.wasOverdue,
      overdueTime: overdueTime ?? this.overdueTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Todo(id: $id, text: $text, completed: $completed, focusedTime: $focusedTime, wasOverdue: $wasOverdue, overdueTime: $overdueTime, createdAt: $createdAt)';
  }
}
