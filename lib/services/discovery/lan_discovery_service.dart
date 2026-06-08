import 'dart:io';
import 'dart:typed_data';

import '../../core/logging/logging_service.dart';
import '../../domain/entities/server_profile.dart';
import '../raknet/raknet_constants.dart';
import '../raknet/raknet_packet_codec.dart';
import 'motd_builder.dart';

class LanDiscoveryService {
  LanDiscoveryService({
    required RakNetPacketCodec rakNetCodec,
    required MotdBuilder motdBuilder,
    required LoggingService logging,
  })  : _rakNetCodec = rakNetCodec,
        _motdBuilder = motdBuilder,
        _logging = logging;

  final RakNetPacketCodec _rakNetCodec;
  final MotdBuilder _motdBuilder;
  final LoggingService _logging;

  bool handleDatagram({
    required RawDatagramSocket socket,
    required Datagram datagram,
    required ServerProfile server,
    required int serverGuid,
  }) {
    final packet = Uint8List.fromList(datagram.data);
    _logging.debug('discovery', 'Inbound UDP packet', <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'direction': 'in',
      'packetId': packet.isEmpty ? null : packet.first,
      'packetName':
          packet.isEmpty ? 'Empty' : RakNetConstants.packetName(packet.first),
      'bytes': packet.length,
      'phase': 'discovery',
    });
    final pingTime = _rakNetCodec.readPingTime(packet);
    if (pingTime == null || !_rakNetCodec.hasMagic(packet, 9)) {
      return false;
    }

    final motd = _motdBuilder.build(server: server, serverGuid: serverGuid);
    final pong = _rakNetCodec.buildUnconnectedPong(
      pingTime: pingTime,
      serverGuid: serverGuid,
      motd: motd,
    );

    final sentBytes = socket.send(pong, datagram.address, datagram.port);
    _logging.debug('discovery', 'Outbound UDP packet', <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'target': datagram.address.address,
      'targetPort': datagram.port,
      'direction': 'out',
      'packetId': RakNetConstants.unconnectedPong,
      'packetName': RakNetConstants.packetName(RakNetConstants.unconnectedPong),
      'bytes': pong.length,
      'phase': 'discovery',
    });
    if (sentBytes != pong.length) {
      _logging.warning('discovery', 'Unconnected pong partially sent',
          <String, Object?>{
        'client': datagram.address.address,
        'clientPort': datagram.port,
        'sentBytes': sentBytes,
        'expectedBytes': pong.length,
      });
      return true;
    }

    _logging.info('discovery', 'Unconnected pong sent', <String, Object?>{
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'motd': motd,
    });
    return true;
  }
}
