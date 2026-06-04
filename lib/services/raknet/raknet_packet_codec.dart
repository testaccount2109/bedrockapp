import 'dart:io';
import 'dart:typed_data';

import '../network/binary_writer.dart';
import 'raknet_constants.dart';

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
}

extension _RakNetAddressWriter on BinaryWriter {
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
