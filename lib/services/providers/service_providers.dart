import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../bedrock/bedrock_networking_service.dart';
import '../host/host_session_manager.dart';

final bedrockNetworkingServiceProvider = Provider<BedrockNetworkingService>((ref) {
  return BedrockNetworkingService(logging: ref.watch(loggingServiceProvider));
});

final hostSessionManagerProvider = Provider<HostSessionManager>((ref) {
  final manager = HostSessionManager(
    networkingService: ref.watch(bedrockNetworkingServiceProvider),
    logging: ref.watch(loggingServiceProvider),
  );
  ref.onDispose(() {
    unawaited(manager.dispose());
  });
  return manager;
});

final hostStatusProvider = StreamProvider((ref) async* {
  final manager = ref.watch(hostSessionManagerProvider);
  yield manager.status;
  yield* manager.statusStream;
});
