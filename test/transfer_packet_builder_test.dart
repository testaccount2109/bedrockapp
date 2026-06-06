import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:host_connect/services/transfer/transfer_packet_builder.dart';

void main() {
  test('builds transfer packet with address port and reload flag', () {
    const builder = TransferPacketBuilder();
    const address = 'play.donutsmp.net';

    final packet = builder.build(
      address: address,
      port: 19132,
      reloadWorld: true,
    );

    final encodedAddress = utf8.encode(address);
    final portOffset = 2 + encodedAddress.length;

    expect(packet.first, TransferPacketBuilder.packetId);
    expect(packet[1], encodedAddress.length);
    expect(utf8.decode(packet.sublist(2, portOffset)), address);
    expect(packet[portOffset], 0xbc);
    expect(packet[portOffset + 1], 0x4a);
    expect(packet[portOffset + 2], 1);
  });
}
