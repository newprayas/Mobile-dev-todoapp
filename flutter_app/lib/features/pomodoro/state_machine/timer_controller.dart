import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';
import 'timer_events.dart';
import 'timer_reducer.dart';
import 'timer_side_effects.dart';
import '../../pomodoro/providers/timer_provider.dart';

/// Controller that serializes events and applies reducer + side effects.
class TimerController {
  final Ref ref;
  final TimerReducer _reducer = const TimerReducer();
  TimerState _state;
  final _queue = <TimerEvent>[];
  bool _processing = false;
  final _sideEffectStream = StreamController<TimerSideEffect>.broadcast();
  Stream<TimerSideEffect> get sideEffects => _sideEffectStream.stream;

  TimerController({required this.ref, required TimerState initial})
    : _state = initial;

  TimerState get state => _state;

  void add(TimerEvent e) {
    _queue.add(e);
    if (!_processing) _drain();
  }

  void _drain() {
    _processing = true;
    while (_queue.isNotEmpty) {
      final ev = _queue.removeAt(0);
      final result = _reducer.reduce(_state, ev);
      _state = result.state;
      for (final eff in result.effects) {
        _sideEffectStream.add(eff);
      }
    }
    _processing = false;
  }

  void dispose() {
    _sideEffectStream.close();
  }
}
