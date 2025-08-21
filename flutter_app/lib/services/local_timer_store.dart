import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_timer_state.dart';

class LocalTimerStore {
  static const key = 'todo_task_timer_states_v1';

  Future<Map<String, TaskTimerState>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final parsed = json.decode(raw) as Map<String, dynamic>;
      final out = <String, TaskTimerState>{};
      parsed.forEach((k, v) {
        out[k] = TaskTimerState.fromJson(Map<String, dynamic>.from(v));
      });
      return out;
    } catch (e) {
      return {};
    }
  }

  Future<void> saveAll(Map<String, TaskTimerState> map) async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = map.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(key, json.encode(serializable));
  }

  Future<void> save(String taskId, TaskTimerState s) async {
    final all = await loadAll();
    all[taskId] = s;
    await saveAll(all);
  }

  Future<TaskTimerState?> load(String taskId) async {
    final all = await loadAll();
    return all[taskId];
  }
}
