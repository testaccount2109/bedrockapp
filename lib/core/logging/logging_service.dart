import 'dart:async';

import 'log_event.dart';
import 'log_level.dart';

class LoggingService {
  LoggingService({int retainedEvents = 500}) : _retainedEvents = retainedEvents;

  final int _retainedEvents;
  final List<LogEvent> _events = <LogEvent>[];
  final StreamController<LogEvent> _controller =
      StreamController<LogEvent>.broadcast();

  List<LogEvent> get events => List<LogEvent>.unmodifiable(_events);

  Stream<LogEvent> get stream => _controller.stream;

  void debug(String category, String message,
      [Map<String, Object?> details = const <String, Object?>{}]) {
    _write(LogLevel.debug, category, message, details);
  }

  void info(String category, String message,
      [Map<String, Object?> details = const <String, Object?>{}]) {
    _write(LogLevel.info, category, message, details);
  }

  void warning(String category, String message,
      [Map<String, Object?> details = const <String, Object?>{}]) {
    _write(LogLevel.warning, category, message, details);
  }

  void error(String category, String message,
      [Map<String, Object?> details = const <String, Object?>{}]) {
    _write(LogLevel.error, category, message, details);
  }

  void _write(
    LogLevel level,
    String category,
    String message,
    Map<String, Object?> details,
  ) {
    final event = LogEvent(
      timestamp: DateTime.now().toUtc(),
      level: level,
      category: category,
      message: message,
      details: details,
    );

    _events.add(event);
    if (_events.length > _retainedEvents) {
      _events.removeRange(0, _events.length - _retainedEvents);
    }
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
