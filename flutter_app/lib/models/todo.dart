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
  });

  factory Todo.fromJson(Map<String, dynamic> j) {
    return Todo(
      id: j['id'] is int ? j['id'] : int.parse('${j['id']}'),
      userId: j['user_id'] ?? j['userId'] ?? '',
      text: j['text'] ?? '',
      completed: (j['completed'] == 1 || j['completed'] == true),
      durationHours: j['duration_hours'] != null
          ? (j['duration_hours'] is int
                ? j['duration_hours']
                : int.parse('${j['duration_hours']}'))
          : 0,
      durationMinutes: j['duration_minutes'] != null
          ? (j['duration_minutes'] is int
                ? j['duration_minutes']
                : int.parse('${j['duration_minutes']}'))
          : 0,
      focusedTime: j['focused_time'] != null
          ? (j['focused_time'] is int
                ? j['focused_time']
                : int.parse('${j['focused_time']}'))
          : 0,
      wasOverdue: j['was_overdue'] != null
          ? (j['was_overdue'] is int
                ? j['was_overdue']
                : int.parse('${j['was_overdue']}'))
          : 0,
      overdueTime: j['overdue_time'] != null
          ? (j['overdue_time'] is int
                ? j['overdue_time']
                : int.parse('${j['overdue_time']}'))
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'text': text,
      'completed': completed ? 1 : 0,
      'duration_hours': durationHours,
      'duration_minutes': durationMinutes,
      'focused_time': focusedTime,
      'was_overdue': wasOverdue,
      'overdue_time': overdueTime,
    };
  }

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
    );
  }
}
