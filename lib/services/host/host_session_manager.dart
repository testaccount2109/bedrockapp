import 'dart:async';

import '../../core/errors/app_failure.dart';
import '../../core/logging/logging_service.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/entities/server_profile.dart';
import '../bedrock/bedrock_networking_service.dart';

class HostSessionManager {
  HostSessionManager({
    required BedrockNetworkingService networkingService,
    required LoggingService logging,
  })  : _networkingService = networkingService,
        _logging = logging;

  final BedrockNetworkingService _networkingService;
  final LoggingService _logging;
  final StreamController<HostStatus> _statusController =
      StreamController<HostStatus>.broadcast();

  HostStatus _status = HostStatus.offline;

  HostStatus get status => _status;
  Stream<HostStatus> get statusStream => _statusController.stream;

  Future<void> start({
    required ServerProfile server,
    required int serverGuid,
  }) async {
    _emit(HostStatus(
      state: HostRunState.starting,
      activeServerName: server.name,
      activeServerHost: server.host,
      activeServerPort: server.port,
      transferCount: _status.transferCount,
      startedAt: null,
      lastError: null,
    ));

    try {
      await _networkingService.start(server: server, serverGuid: serverGuid);
      _emit(HostStatus(
        state: HostRunState.online,
        activeServerName: server.name,
        activeServerHost: server.host,
        activeServerPort: server.port,
        transferCount: _status.transferCount,
        startedAt: DateTime.now(),
        lastError: null,
      ));
      _logging.info('host', 'Host session online', <String, Object?>{
        'serverName': server.name,
        'targetHost': server.host,
        'targetPort': server.port,
      });
    } on AppFailure catch (error) {
      _emit(_status.copyWith(
        state: HostRunState.failed,
        lastError: error.message,
      ));
      _logging.error('host', 'Host session failed',
          <String, Object?>{'error': error.toString()});
    } on Object catch (error) {
      _emit(_status.copyWith(
        state: HostRunState.failed,
        lastError: error.toString(),
      ));
      _logging.error('host', 'Unexpected host session failure',
          <String, Object?>{'error': error.toString()});
    }
  }

  Future<void> stop() async {
    if (_status.state == HostRunState.offline) {
      return;
    }
    _emit(_status.copyWith(state: HostRunState.stopping));
    await _networkingService.stop();
    _emit(HostStatus.offline.copyWith(transferCount: _status.transferCount));
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  void _emit(HostStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
