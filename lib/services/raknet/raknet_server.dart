import 'dart:io';
import 'dart:typed_data';

import '../../core/logging/logging_service.dart';
import 'raknet_constants.dart';
import 'raknet_packet_codec.dart';

class RakNetServer {
  RakNetServer({
    required RakNetPacketCodec codec,
    required LoggingService logging,
  })  : _codec = codec,
        _logging = logging;

  final RakNetPacketCodec _codec;
  final LoggingService _logging;

  bool handleDatagram({
    required RawDatagramSocket socket,
    required Datagram datagram,
    required int serverGuid,
  }) {
    final packet = Uint8List.fromList(datagram.data);
    if (packet.isEmpty) {
      return false;
    }

    switch (packet.first) {
      case RakNetConstants.openConnectionRequest1:
        return _replyOpenConnection1(socket, datagram, packet, serverGuid);
      case RakNetConstants.openConnectionRequest2:
        return _replyOpenConnection2(socket, datagram, packet, serverGuid);
      default:
        return false;
    }
  }

  bool _replyOpenConnection1(
    RawDatagramSocket socket,
    Datagram datagram,
    Uint8List packet,
    int serverGuid,
  ) {
    if (!_codec.hasMagic(packet, 1)) {
      return false;
    }
    final mtu = _codec.readMtuFromRequest1(packet);
    final reply = _codec.buildOpenConnectionReply1(
      serverGuid: serverGuid,
      mtu: mtu,
    );
    final sentBytes = socket.send(reply, datagram.address, datagram.port);
    if (sentBytes != reply.length) {
      _logging.warning('raknet', 'Open connection reply 1 partially sent',
          <String, Object?>{
        'client': datagram.address.address,
        'clientPort': datagram.port,
        'sentBytes': sentBytes,
        'expectedBytes': reply.length,
      });
      return true;
    }
    _logging.info('raknet', 'Open connection reply 1 sent', <String, Object?>{
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'mtu': mtu,
    });
    return true;
  }

  bool _replyOpenConnection2(
    RawDatagramSocket socket,
    Datagram datagram,
    Uint8List packet,
    int serverGuid,
  ) {
    if (!_codec.hasMagic(packet, 1)) {
      return false;
    }
    final mtu = _codec.readMtuFromRequest2(packet);
    final reply = _codec.buildOpenConnectionReply2(
      serverGuid: serverGuid,
      clientAddress: datagram.address,
      clientPort: datagram.port,
      mtu: mtu,
    );
    final sentBytes = socket.send(reply, datagram.address, datagram.port);
    if (sentBytes != reply.length) {
      _logging.warning('raknet', 'Open connection reply 2 partially sent',
          <String, Object?>{
        'client': datagram.address.address,
        'clientPort': datagram.port,
        'sentBytes': sentBytes,
        'expectedBytes': reply.length,
      });
      return true;
    }
    _logging.info('raknet', 'Open connection reply 2 sent', <String, Object?>{
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'mtu': mtu,
    });
    return true;
  }
}
