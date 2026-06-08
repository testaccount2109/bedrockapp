import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:host_connect/services/raknet/raknet_constants.dart';
import 'package:host_connect/services/raknet/raknet_packet_codec.dart';
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

  test('builds unconnected ping used for iOS local network permission probe', () {
    const codec = RakNetPacketCodec();

    final packet = codec.buildUnconnectedPing(
      pingTime: 123,
      clientGuid: 456,
    );

    expect(packet.first, RakNetConstants.unconnectedPing);
    expect(codec.readPingTime(packet), 123);
    expect(codec.hasMagic(packet, 9), isTrue);
    expect(packet.length, 33);
  });

  test('parses RakNet frame set packet id 132', () {
    const codec = RakNetPacketCodec();
    final packet = Uint8List.fromList(<int>[
      0x84,
      0x2a,
      0x00,
      0x00,
      0x60,
      0x00,
      0x90,
      0x01,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      RakNetConstants.connectionRequest,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      7,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      8,
      0,
    ]);

    final frameSet = codec.readFrameSet(packet);

    expect(frameSet, isNotNull);
    expect(frameSet!.sequenceNumber, 42);
    expect(frameSet.frames, hasLength(1));
    expect(frameSet.frames.single.payload.first,
        RakNetConstants.connectionRequest);
    expect(codec.readConnectionRequestTimestamp(frameSet.frames.single.payload),
        8);
  });

  test('builds ACK and connection request accepted frame set', () {
    const codec = RakNetPacketCodec();

    final ack = codec.buildAck(42);
    expect(ack, <int>[RakNetConstants.ack, 0, 1, 1, 42, 0, 0]);

    final accepted = codec.buildConnectionRequestAccepted(
      clientAddress: InternetAddress('192.168.1.5'),
      clientPort: 19132,
      clientTimestamp: 8,
      serverTimestamp: 9,
    );
    expect(accepted.first, RakNetConstants.connectionRequestAccepted);

    final frameSet = codec.buildFrameSet(
      sequenceNumber: 0,
      reliableIndex: 0,
      orderIndex: 0,
      payload: accepted,
    );
    expect(frameSet.first, 0x80);
    final parsed = codec.readFrameSet(frameSet);
    expect(parsed!.frames.single.payload.first,
        RakNetConstants.connectionRequestAccepted);
  });
}
