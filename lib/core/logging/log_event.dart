import 'log_level.dart';

class LogEvent {
  const LogEvent({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, Object?> details;
}
