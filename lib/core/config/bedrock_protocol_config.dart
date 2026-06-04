class BedrockProtocolConfig {
  const BedrockProtocolConfig({
    required this.protocolVersion,
    required this.versionName,
    required this.ipv4Port,
    required this.ipv6Port,
    required this.maxPlayers,
  });

  final int protocolVersion;
  final String versionName;
  final int ipv4Port;
  final int ipv6Port;
  final int maxPlayers;

  static const current = BedrockProtocolConfig(
    protocolVersion: 818,
    versionName: '1.21.130',
    ipv4Port: 19132,
    ipv6Port: 19133,
    maxPlayers: 1,
  );
}
