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
}
