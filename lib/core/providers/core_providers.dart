import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/log_event.dart';
import '../logging/logging_service.dart';

final loggingServiceProvider = Provider<LoggingService>((ref) {
  final service = LoggingService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final logEventsProvider = StreamProvider<List<LogEvent>>((ref) async* {
  final logging = ref.watch(loggingServiceProvider);
  yield logging.events;
  await for (final _ in logging.stream) {
    yield logging.events;
  }
});
