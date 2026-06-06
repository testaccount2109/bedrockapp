import 'dart:async';
import 'dart:io';

import '../../core/config/bedrock_protocol_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/logging/logging_service.dart';
import '../../domain/entities/server_profile.dart';
import '../discovery/lan_discovery_service.dart';
import '../discovery/motd_builder.dart';
import '../raknet/raknet_packet_codec.dart';
import '../raknet/raknet_server.dart';

class BedrockNetworkingService {
  BedrockNetworkingService({
    required LoggingService logging,
    BedrockProtocolConfig config = BedrockProtocolConfig.current,
  })  : _logging = logging,
        _config = config {
    final codec = RakNetPacketCodec();
    _discovery = LanDiscoveryService(
      rakNetCodec: codec,
      motdBuilder: MotdBuilder(config),
      logging: logging,
    );
    _rakNetServer = RakNetServer(codec: codec, logging: logging);
  }

  final LoggingService _logging;
  final BedrockProtocolConfig _config;
  late final LanDiscoveryService _discovery;
  late final RakNetServer _rakNetServer;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  ServerProfile? _activeServer;
  int? _serverGuid;

  bool get isRunning => _socket != null;

  Future<void> start({
    required ServerProfile server,
    required int serverGuid,
  }) async {
    if (isRunning) {
      await stop();
    }

    _activeServer = server;
    _serverGuid = serverGuid;

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _config.ipv4Port,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;
      _socket = socket;
      _subscription = socket.listen(
        _handleSocketEvent,
        onError: (Object error) {
          _logging.error('network', 'UDP socket stream failed',
              <String, Object?>{'error': error.toString()});
        },
        onDone: () {
          _logging.info('network', 'UDP socket stream closed');
        },
      );

      _logging.info('network', 'Bedrock UDP service started', <String, Object?>{
        'address': InternetAddress.anyIPv4.address,
        'port': _config.ipv4Port,
        'serverName': server.lanName,
      });
    } on SocketException catch (error) {
      _activeServer = null;
      _serverGuid = null;
      throw NetworkFailure('Unable to bind UDP ${_config.ipv4Port}', error);
    }
  }

  Future<void> stop() async {
    final socket = _socket;
    _socket = null;
    _activeServer = null;
    _serverGuid = null;
    await _subscription?.cancel();
    _subscription = null;
    socket?.close();
    _logging.info('network', 'Bedrock UDP service stopped');
  }

  void _handleSocketEvent(RawSocketEvent event) {
    final socket = _socket;
    final server = _activeServer;
    final serverGuid = _serverGuid;
    if (socket == null || server == null || serverGuid == null) {
      return;
    }
    if (event != RawSocketEvent.read) {
      return;
    }

    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final received = datagram!;
      bool handledByDiscovery;
      bool handledByRakNet;
      try {
        handledByDiscovery = _discovery.handleDatagram(
          socket: socket,
          datagram: received,
          server: server,
          serverGuid: serverGuid,
        );
        if (handledByDiscovery) {
          continue;
        }

        handledByRakNet = _rakNetServer.handleDatagram(
          socket: socket,
          datagram: received,
          serverGuid: serverGuid,
        );
        if (handledByRakNet) {
          continue;
        }
      } on Object catch (error) {
        _logging.error('network', 'UDP datagram handling failed',
            <String, Object?>{
          'client': received.address.address,
          'clientPort': received.port,
          'bytes': received.data.length,
          'error': error.toString(),
        });
        continue;
      }

      _logging.debug('network', 'Unhandled UDP datagram',
          <String, Object?>{
        'client': received.address.address,
        'clientPort': received.port,
        'bytes': received.data.length,
        'packetId': received.data.isEmpty ? null : received.data.first,
      });
    }
  }
}
