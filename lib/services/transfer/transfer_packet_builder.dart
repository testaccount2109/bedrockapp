import 'dart:typed_data';

import '../network/binary_writer.dart';

class TransferPacketBuilder {
  const TransferPacketBuilder();

  static const int packetId = 0x55;

  Uint8List build({
    required String address,
    required int port,
    required bool reloadWorld,
  }) {
    final writer = BinaryWriter()
      ..writeVarUint(packetId)
      ..writeVarString(address)
      ..writeUint16LittleEndian(port)
      ..writeBool(reloadWorld);
    return writer.takeBytes();
  }
}
