class RakNetConstants {
  static const List<int> magic = <int>[
    0x00,
    0xff,
    0xff,
    0x00,
    0xfe,
    0xfe,
    0xfe,
    0xfe,
    0xfd,
    0xfd,
    0xfd,
    0xfd,
    0x12,
    0x34,
    0x56,
    0x78,
  ];

  static const int unconnectedPing = 0x01;
  static const int unconnectedPong = 0x1c;
  static const int openConnectionRequest1 = 0x05;
  static const int openConnectionReply1 = 0x06;
  static const int openConnectionRequest2 = 0x07;
  static const int openConnectionReply2 = 0x08;

  static const int connectedPing = 0x00;
  static const int connectedPong = 0x03;
  static const int connectionRequest = 0x09;
  static const int connectionRequestAccepted = 0x10;
  static const int newIncomingConnection = 0x13;
  static const int gamePacket = 0xfe;

  static const int nack = 0xa0;
  static const int ack = 0xc0;

  static bool isFrameSet(int packetId) => packetId >= 0x80 && packetId <= 0x8f;

  static String packetName(int packetId) {
    if (isFrameSet(packetId)) {
      return 'Frame Set';
    }
    return switch (packetId) {
      unconnectedPing => 'Unconnected Ping',
      unconnectedPong => 'Unconnected Pong',
      openConnectionRequest1 => 'Open Connection Request 1',
      openConnectionReply1 => 'Open Connection Reply 1',
      openConnectionRequest2 => 'Open Connection Request 2',
      openConnectionReply2 => 'Open Connection Reply 2',
      connectedPing => 'Connected Ping',
      connectedPong => 'Connected Pong',
      connectionRequest => 'Connection Request',
      connectionRequestAccepted => 'Connection Request Accepted',
      newIncomingConnection => 'New Incoming Connection',
      gamePacket => 'Game Packet',
      ack => 'ACK',
      nack => 'NACK',
      _ => 'Unknown',
    };
  }
}
