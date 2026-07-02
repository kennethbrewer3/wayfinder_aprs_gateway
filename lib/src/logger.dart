import 'dart:convert';
import 'dart:io';

enum LogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3);

  const LogLevel(this.priority);

  final int priority;

  static LogLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warn':
      case 'warning':
        return LogLevel.warn;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

class StructuredLogger {
  StructuredLogger(this.minLevel);

  final LogLevel minLevel;

  void debug(String message, {Map<String, Object?> fields = const {}}) {
    _log(LogLevel.debug, message, fields);
  }

  void info(String message, {Map<String, Object?> fields = const {}}) {
    _log(LogLevel.info, message, fields);
  }

  void warn(String message, {Map<String, Object?> fields = const {}}) {
    _log(LogLevel.warn, message, fields);
  }

  void error(String message, {Map<String, Object?> fields = const {}}) {
    _log(LogLevel.error, message, fields);
  }

  void _log(LogLevel level, String message, Map<String, Object?> fields) {
    if (level.priority < minLevel.priority) return;

    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level.name,
      'message': message,
      if (fields.isNotEmpty) ...fields,
    };

    stdout.writeln(jsonEncode(record));
  }
}
