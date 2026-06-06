import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

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
  static const MethodChannel _localNetworkChannel =
      MethodChannel('de.hostconnect.app/local_network');
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
      await _triggerLocalNetworkPermissionIfNeeded(serverGuid);
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
    } on AppFailure {
      _activeServer = null;
      _serverGuid = null;
      rethrow;
    }
  }

  Future<void> _triggerLocalNetworkPermissionIfNeeded(int serverGuid) async {
    if (!Platform.isIOS) {
      return;
    }

    _logging.info('network', 'iOS local network permission probe started',
        <String, Object?>{
      'port': _config.ipv4Port,
      'nativeProbe': true,
      'udpFallback': true,
    });
    await _logLocalNetworkInterfaces();
    await _requestLocalNetworkPermissionWithNetworkFramework();
    await _sendLocalNetworkUdpProbe(serverGuid);
  }

  Future<void> _requestLocalNetworkPermissionWithNetworkFramework() async {
    try {
      final response = await _localNetworkChannel
          .invokeMapMethod<String, Object?>('request')
          .timeout(const Duration(seconds: 6));
      final status = response?['status']?.toString() ?? 'missing';
      final message = response?['message']?.toString() ?? '';
      final durationMs = response?['durationMs'];
      final serviceType = response?['serviceType']?.toString();

      _logging.info('network', 'iOS Network.framework probe completed',
          <String, Object?>{
        'status': status,
        'message': message,
        'durationMs': durationMs,
        'serviceType': serviceType,
      });

      if (status == 'failed' ||
          status == 'waiting' ||
          status == 'cancelled' ||
          status == 'unknown' ||
          status == 'missing') {
        throw NetworkFailure(
          'iOS local network permission probe failed with status $status',
          message,
        );
      }
    } on TimeoutException catch (error) {
      _logging.warning('network', 'iOS Network.framework probe timed out',
          <String, Object?>{'error': error.toString()});
      throw NetworkFailure(
        'iOS local network permission probe timed out',
        error,
      );
    } on PlatformException catch (error) {
      _logging.warning('network', 'iOS Network.framework probe failed',
          <String, Object?>{
        'code': error.code,
        'message': error.message,
        'details': error.details?.toString(),
      });
      throw NetworkFailure(
        'iOS local network permission could not be requested',
        error,
      );
    }
  }

  Future<void> _sendLocalNetworkUdpProbe(int serverGuid) async {
    RawDatagramSocket? probeSocket;
    try {
      probeSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      probeSocket.broadcastEnabled = true;
      final probe = RakNetPacketCodec().buildUnconnectedPing(
        pingTime: DateTime.now().millisecondsSinceEpoch,
        clientGuid: serverGuid,
      );
      final sentBytes = probeSocket.send(
        probe,
        InternetAddress('255.255.255.255'),
        _config.ipv4Port,
      );

      _logging.info('network', 'iOS UDP broadcast probe completed',
          <String, Object?>{
        'address': '255.255.255.255',
        'port': _config.ipv4Port,
        'sentBytes': sentBytes,
        'expectedBytes': probe.length,
        'fullySent': sentBytes == probe.length,
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } on SocketException catch (error) {
      _logging.warning('network', 'iOS UDP broadcast probe failed',
          <String, Object?>{'error': error.toString()});
      throw NetworkFailure(
        'iOS UDP broadcast is required for Bedrock LAN discovery',
        error,
      );
    } finally {
      probeSocket?.close();
    }
  }

  Future<void> _logLocalNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      _logging.info('network', 'Local IPv4 interfaces detected',
          <String, Object?>{
        'interfaceCount': interfaces.length,
        'interfaces': interfaces
            .map((interface) => <String, Object?>{
                  'name': interface.name,
                  'index': interface.index,
                  'addresses': interface.addresses
                      .map((address) => address.address)
                      .toList(growable: false),
                })
            .toList(growable: false),
      });
    } on SocketException catch (error) {
      _logging.warning('network', 'Unable to list local network interfaces',
          <String, Object?>{'error': error.toString()});
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
