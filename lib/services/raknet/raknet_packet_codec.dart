import 'dart:io';
import 'dart:typed_data';

import '../network/binary_writer.dart';
import 'raknet_constants.dart';

class RakNetFrame {
  const RakNetFrame({
    required this.payload,
    required this.reliability,
    required this.reliableIndex,
    required this.orderIndex,
    required this.orderChannel,
  });

  final Uint8List payload;
  final int reliability;
  final int? reliableIndex;
  final int? orderIndex;
  final int? orderChannel;
}

class RakNetFrameSet {
  const RakNetFrameSet({
    required this.sequenceNumber,
    required this.frames,
  });

  final int sequenceNumber;
  final List<RakNetFrame> frames;
}

class RakNetPacketCodec {
  const RakNetPacketCodec();

  bool hasMagic(Uint8List packet, int offset) {
    final magic = RakNetConstants.magic;
    if (packet.length < offset + magic.length) {
      return false;
    }
    for (var index = 0; index < magic.length; index++) {
      if (packet[offset + index] != magic[index]) {
        return false;
      }
    }
    return true;
  }

  int? readPingTime(Uint8List packet) {
    if (packet.length < 9 || packet.first != RakNetConstants.unconnectedPing) {
      return null;
    }
    return ByteData.sublistView(packet, 1, 9).getUint64(0, Endian.big);
  }

  int readMtuFromRequest1(Uint8List packet) {
    return packet.length.clamp(400, 1492);
  }

  int readMtuFromRequest2(Uint8List packet) {
    if (packet.length < 35) {
      return 1400;
    }
    return ByteData.sublistView(packet, packet.length - 10, packet.length - 8)
        .getUint16(0, Endian.big)
        .clamp(400, 1492);
  }

  Uint8List buildUnconnectedPong({
    required int pingTime,
    required int serverGuid,
    required String motd,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.unconnectedPong)
      ..writeUint64BigEndian(pingTime)
      ..writeUint64BigEndian(serverGuid)
      ..writeBytes(RakNetConstants.magic)
      ..writeRakNetString(motd);
    return writer.takeBytes();
  }

  Uint8List buildUnconnectedPing({
    required int pingTime,
    required int clientGuid,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.unconnectedPing)
      ..writeUint64BigEndian(pingTime)
      ..writeBytes(RakNetConstants.magic)
      ..writeUint64BigEndian(clientGuid);
    return writer.takeBytes();
  }

  Uint8List buildOpenConnectionReply1({
    required int serverGuid,
    required int mtu,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.openConnectionReply1)
      ..writeBytes(RakNetConstants.magic)
      ..writeUint64BigEndian(serverGuid)
      ..writeBool(false)
      ..writeUint16BigEndian(mtu);
    return writer.takeBytes();
  }

  Uint8List buildOpenConnectionReply2({
    required int serverGuid,
    required InternetAddress clientAddress,
    required int clientPort,
    required int mtu,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.openConnectionReply2)
      ..writeBytes(RakNetConstants.magic)
      ..writeUint64BigEndian(serverGuid)
      ..writeRakNetAddress(clientAddress, clientPort)
      ..writeUint16BigEndian(mtu)
      ..writeBool(false);
    return writer.takeBytes();
  }

  RakNetFrameSet? readFrameSet(Uint8List packet) {
    if (packet.length < 4 || !RakNetConstants.isFrameSet(packet.first)) {
      return null;
    }

    var offset = 4;
    final frames = <RakNetFrame>[];
    while (offset < packet.length) {
      if (offset + 3 > packet.length) {
        return null;
      }
      final flags = packet[offset++];
      final reliability = flags >> 5;
      final hasSplit = (flags & 0x10) != 0;
      final payloadBitLength =
          ByteData.sublistView(packet, offset, offset + 2).getUint16(
        0,
        Endian.big,
      );
      offset += 2;

      int? reliableIndex;
      int? orderIndex;
      int? orderChannel;
      if (_hasReliableIndex(reliability)) {
        if (offset + 3 > packet.length) {
          return null;
        }
        reliableIndex = _readUint24LittleEndian(packet, offset);
        offset += 3;
      }
      if (_hasOrderIndex(reliability)) {
        if (offset + 4 > packet.length) {
          return null;
        }
        orderIndex = _readUint24LittleEndian(packet, offset);
        offset += 3;
        orderChannel = packet[offset++];
      }
      if (hasSplit) {
        if (offset + 10 > packet.length) {
          return null;
        }
        offset += 10;
      }

      final payloadLength = (payloadBitLength + 7) ~/ 8;
      if (offset + payloadLength > packet.length) {
        return null;
      }
      frames.add(RakNetFrame(
        payload: Uint8List.sublistView(packet, offset, offset + payloadLength),
        reliability: reliability,
        reliableIndex: reliableIndex,
        orderIndex: orderIndex,
        orderChannel: orderChannel,
      ));
      offset += payloadLength;
    }

    return RakNetFrameSet(
      sequenceNumber: _readUint24LittleEndian(packet, 1),
      frames: frames,
    );
  }

  Uint8List buildAck(int sequenceNumber) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.ack)
      ..writeUint16BigEndian(1)
      ..writeBool(true)
      ..writeUint24LittleEndian(sequenceNumber);
    return writer.takeBytes();
  }

  Uint8List buildFrameSet({
    required int sequenceNumber,
    required int reliableIndex,
    required int orderIndex,
    required Uint8List payload,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(0x80)
      ..writeUint24LittleEndian(sequenceNumber)
      ..writeUint8(0x60)
      ..writeUint16BigEndian(payload.length * 8)
      ..writeUint24LittleEndian(reliableIndex)
      ..writeUint24LittleEndian(orderIndex)
      ..writeUint8(0)
      ..writeBytes(payload);
    return writer.takeBytes();
  }

  Uint8List buildConnectionRequestAccepted({
    required InternetAddress clientAddress,
    required int clientPort,
    required int clientTimestamp,
    required int serverTimestamp,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.connectionRequestAccepted)
      ..writeRakNetAddress(clientAddress, clientPort)
      ..writeUint16BigEndian(0);
    for (var index = 0; index < 20; index++) {
      writer.writeRakNetAddress(InternetAddress('255.255.255.255'), 0);
    }
    writer
      ..writeUint64BigEndian(clientTimestamp)
      ..writeUint64BigEndian(serverTimestamp);
    return writer.takeBytes();
  }

  int? readConnectionRequestTimestamp(Uint8List payload) {
    if (payload.length < 17 ||
        payload.first != RakNetConstants.connectionRequest) {
      return null;
    }
    return ByteData.sublistView(payload, 9, 17).getUint64(0, Endian.big);
  }

  int? readConnectedPingTimestamp(Uint8List payload) {
    if (payload.length < 9 || payload.first != RakNetConstants.connectedPing) {
      return null;
    }
    return ByteData.sublistView(payload, 1, 9).getUint64(0, Endian.big);
  }

  Uint8List buildConnectedPong({
    required int pingTimestamp,
    required int pongTimestamp,
  }) {
    final writer = BinaryWriter()
      ..writeUint8(RakNetConstants.connectedPong)
      ..writeUint64BigEndian(pingTimestamp)
      ..writeUint64BigEndian(pongTimestamp);
    return writer.takeBytes();
  }

  static int _readUint24LittleEndian(Uint8List packet, int offset) {
    return packet[offset] |
        (packet[offset + 1] << 8) |
        (packet[offset + 2] << 16);
  }

  static bool _hasReliableIndex(int reliability) {
    return reliability == 2 ||
        reliability == 3 ||
        reliability == 4 ||
        reliability == 6 ||
        reliability == 7;
  }

  static bool _hasOrderIndex(int reliability) {
    return reliability == 1 ||
        reliability == 3 ||
        reliability == 4 ||
        reliability == 7;
  }
}

extension RakNetAddressWriter on BinaryWriter {
  void writeRakNetAddress(InternetAddress address, int port) {
    if (address.type != InternetAddressType.IPv4) {
      writeUint8(6);
      for (var i = 0; i < 16; i++) {
        writeUint8(0);
      }
      writeUint16BigEndian(port);
      return;
    }

    writeUint8(4);
    for (final octet in address.rawAddress) {
      writeUint8(octet ^ 0xff);
    }
    writeUint16BigEndian(port);
  }
}
