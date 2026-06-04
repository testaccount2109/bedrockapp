import 'dart:io';
import 'dart:typed_data';

import '../../core/logging/logging_service.dart';
import '../../domain/entities/server_profile.dart';
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
