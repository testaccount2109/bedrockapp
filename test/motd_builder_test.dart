import 'package:flutter_test/flutter_test.dart';
import 'package:host_connect/core/config/bedrock_protocol_config.dart';
import 'package:host_connect/domain/entities/server_profile.dart';
import 'package:host_connect/services/discovery/motd_builder.dart';

void main() {
  test('builds a Bedrock LAN MOTD with dynamic HostConnect name', () {
    const builder = MotdBuilder(BedrockProtocolConfig.current);
    const server = ServerProfile(
      id: 'server-1',
      name: 'DonutSMP',
      host: 'play.donutsmp.net',
      port: 19132,
      isFavorite: true,
    );

    final motd = builder.build(server: server, serverGuid: 42);

    expect(motd, contains('MCPE;HostConnect - DonutSMP;'));
    expect(motd, contains(';818;1.21.130;'));
    expect(motd, endsWith('19132;19133;'));
  });
}
