import 'dart:io';
import 'dart:typed_data';

import '../../core/logging/logging_service.dart';
import 'raknet_constants.dart';
import 'raknet_packet_codec.dart';

enum _RakNetPhase {
  offline,
  opening,
  connected,
  bedrock,
}

class _RakNetSession {
  _RakNetPhase phase = _RakNetPhase.offline;
  int outgoingSequence = 0;
  int outgoingReliableIndex = 0;
  int outgoingOrderIndex = 0;
}

class RakNetServer {
  RakNetServer({
    required RakNetPacketCodec codec,
    required LoggingService logging,
  })  : _codec = codec,
        _logging = logging;

  final RakNetPacketCodec _codec;
  final LoggingService _logging;
  final Map<String, _RakNetSession> _sessions = <String, _RakNetSession>{};

  bool handleDatagram({
    required RawDatagramSocket socket,
    required Datagram datagram,
    required int serverGuid,
  }) {
    final packet = Uint8List.fromList(datagram.data);
    if (packet.isEmpty) {
      return false;
    }

    _logInbound(datagram, packet.first, packet.length, _phaseFor(datagram));

    switch (packet.first) {
      case RakNetConstants.openConnectionRequest1:
        return _replyOpenConnection1(socket, datagram, packet, serverGuid);
      case RakNetConstants.openConnectionRequest2:
        return _replyOpenConnection2(socket, datagram, packet, serverGuid);
      case RakNetConstants.ack:
      case RakNetConstants.nack:
        return true;
      default:
        if (RakNetConstants.isFrameSet(packet.first)) {
          return _handleFrameSet(socket, datagram, packet);
        }
        return false;
    }
  }

  void reset() {
    _sessions.clear();
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
    _sessionFor(datagram).phase = _RakNetPhase.opening;
    final reply = _codec.buildOpenConnectionReply1(
      serverGuid: serverGuid,
      mtu: mtu,
    );
    final sentBytes = socket.send(reply, datagram.address, datagram.port);
    _logOutbound(
      datagram,
      RakNetConstants.openConnectionReply1,
      reply.length,
      _RakNetPhase.opening,
    );
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
    _sessionFor(datagram).phase = _RakNetPhase.opening;
    final reply = _codec.buildOpenConnectionReply2(
      serverGuid: serverGuid,
      clientAddress: datagram.address,
      clientPort: datagram.port,
      mtu: mtu,
    );
    final sentBytes = socket.send(reply, datagram.address, datagram.port);
    _logOutbound(
      datagram,
      RakNetConstants.openConnectionReply2,
      reply.length,
      _RakNetPhase.opening,
    );
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

  bool _handleFrameSet(
    RawDatagramSocket socket,
    Datagram datagram,
    Uint8List packet,
  ) {
    final frameSet = _codec.readFrameSet(packet);
    if (frameSet == null) {
      _logging.warning('raknet', 'Malformed RakNet frame set received',
          <String, Object?>{
        'client': datagram.address.address,
        'clientPort': datagram.port,
        'packetId': packet.first,
        'packetName': RakNetConstants.packetName(packet.first),
        'bytes': packet.length,
        'phase': _phaseFor(datagram).name,
      });
      return true;
    }

    final ack = _codec.buildAck(frameSet.sequenceNumber);
    socket.send(ack, datagram.address, datagram.port);
    _logOutbound(datagram, RakNetConstants.ack, ack.length, _phaseFor(datagram));

    for (final frame in frameSet.frames) {
      if (frame.payload.isEmpty) {
        continue;
      }
      final payloadId = frame.payload.first;
      _logging.debug('raknet', 'RakNet frame payload received',
          <String, Object?>{
        'time': DateTime.now().toUtc().toIso8601String(),
        'client': datagram.address.address,
        'clientPort': datagram.port,
        'outerPacketId': packet.first,
        'outerPacketName': RakNetConstants.packetName(packet.first),
        'packetId': payloadId,
        'packetName': RakNetConstants.packetName(payloadId),
        'bytes': frame.payload.length,
        'phase': _phaseFor(datagram).name,
        'sequenceNumber': frameSet.sequenceNumber,
        'reliability': frame.reliability,
        'reliableIndex': frame.reliableIndex,
        'orderIndex': frame.orderIndex,
        'orderChannel': frame.orderChannel,
      });

      switch (payloadId) {
        case RakNetConstants.connectedPing:
          _replyConnectedPing(socket, datagram, frame.payload);
          break;
        case RakNetConstants.connectionRequest:
          _acceptConnection(socket, datagram, frame.payload);
          break;
        case RakNetConstants.newIncomingConnection:
          _sessionFor(datagram).phase = _RakNetPhase.bedrock;
          _logging.info('raknet', 'RakNet new incoming connection received',
              <String, Object?>{
            'client': datagram.address.address,
            'clientPort': datagram.port,
            'phase': _RakNetPhase.bedrock.name,
          });
          break;
        case RakNetConstants.gamePacket:
          _logging.info('bedrock', 'Bedrock game packet received',
              <String, Object?>{
            'client': datagram.address.address,
            'clientPort': datagram.port,
            'bytes': frame.payload.length,
            'phase': _RakNetPhase.bedrock.name,
            'note': 'Bedrock Login phase starts here',
          });
          break;
        default:
          _logging.debug('raknet', 'Unhandled RakNet frame payload',
              <String, Object?>{
            'client': datagram.address.address,
            'clientPort': datagram.port,
            'packetId': payloadId,
            'packetName': RakNetConstants.packetName(payloadId),
            'phase': _phaseFor(datagram).name,
          });
          break;
      }
    }

    return true;
  }

  void _acceptConnection(
    RawDatagramSocket socket,
    Datagram datagram,
    Uint8List payload,
  ) {
    final session = _sessionFor(datagram)..phase = _RakNetPhase.connected;
    final clientTimestamp =
        _codec.readConnectionRequestTimestamp(payload) ??
            DateTime.now().millisecondsSinceEpoch;
    final accepted = _codec.buildConnectionRequestAccepted(
      clientAddress: datagram.address,
      clientPort: datagram.port,
      clientTimestamp: clientTimestamp,
      serverTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final frameSet = _codec.buildFrameSet(
      sequenceNumber: session.outgoingSequence++,
      reliableIndex: session.outgoingReliableIndex++,
      orderIndex: session.outgoingOrderIndex++,
      payload: accepted,
    );
    socket.send(frameSet, datagram.address, datagram.port);
    _logOutbound(datagram, 0x80, frameSet.length, session.phase);
    _logging.info('raknet', 'Connection request accepted', <String, Object?>{
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'phase': session.phase.name,
      'payloadPacketId': RakNetConstants.connectionRequestAccepted,
      'payloadPacketName':
          RakNetConstants.packetName(RakNetConstants.connectionRequestAccepted),
    });
  }

  void _replyConnectedPing(
    RawDatagramSocket socket,
    Datagram datagram,
    Uint8List payload,
  ) {
    final session = _sessionFor(datagram);
    final pingTimestamp =
        _codec.readConnectedPingTimestamp(payload) ??
            DateTime.now().millisecondsSinceEpoch;
    final pong = _codec.buildConnectedPong(
      pingTimestamp: pingTimestamp,
      pongTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final frameSet = _codec.buildFrameSet(
      sequenceNumber: session.outgoingSequence++,
      reliableIndex: session.outgoingReliableIndex++,
      orderIndex: session.outgoingOrderIndex++,
      payload: pong,
    );
    socket.send(frameSet, datagram.address, datagram.port);
    _logOutbound(datagram, 0x80, frameSet.length, session.phase);
    _logging.info('raknet', 'Connected pong sent', <String, Object?>{
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'phase': session.phase.name,
      'payloadPacketId': RakNetConstants.connectedPong,
      'payloadPacketName':
          RakNetConstants.packetName(RakNetConstants.connectedPong),
    });
  }

  _RakNetSession _sessionFor(Datagram datagram) {
    return _sessions.putIfAbsent(
      _sessionKey(datagram),
      _RakNetSession.new,
    );
  }

  _RakNetPhase _phaseFor(Datagram datagram) {
    return _sessions[_sessionKey(datagram)]?.phase ?? _RakNetPhase.offline;
  }

  String _sessionKey(Datagram datagram) {
    return '${datagram.address.address}:${datagram.port}';
  }

  void _logInbound(
    Datagram datagram,
    int packetId,
    int bytes,
    _RakNetPhase phase,
  ) {
    _logging.debug('raknet', 'Inbound UDP packet', <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'client': datagram.address.address,
      'clientPort': datagram.port,
      'direction': 'in',
      'packetId': packetId,
      'packetName': RakNetConstants.packetName(packetId),
      'bytes': bytes,
      'phase': phase.name,
    });
  }

  void _logOutbound(
    Datagram datagram,
    int packetId,
    int bytes,
    _RakNetPhase phase,
  ) {
    _logging.debug('raknet', 'Outbound UDP packet', <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'target': datagram.address.address,
      'targetPort': datagram.port,
      'direction': 'out',
      'packetId': packetId,
      'packetName': RakNetConstants.packetName(packetId),
      'bytes': bytes,
      'phase': phase.name,
    });
  }
}
