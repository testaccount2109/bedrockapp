import '../../core/config/bedrock_protocol_config.dart';
import '../../domain/entities/server_profile.dart';

class MotdBuilder {
  const MotdBuilder(this.config);

  final BedrockProtocolConfig config;

  String build({
    required ServerProfile server,
    required int serverGuid,
    int playerCount = 0,
  }) {
    final safeName = _sanitize(server.lanName);
    return <String>[
      'MCPE',
      safeName,
      config.protocolVersion.toString(),
      config.versionName,
      playerCount.toString(),
      config.maxPlayers.toString(),
      serverGuid.toString(),
      'HostConnect',
      'Survival',
      '1',
      config.ipv4Port.toString(),
      config.ipv6Port.toString(),
      '',
    ].join(';');
  }

  String _sanitize(String value) {
    return value.replaceAll(';', ' ').replaceAll('\n', ' ').trim();
  }
}
