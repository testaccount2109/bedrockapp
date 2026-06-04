class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.isFavorite,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final bool isFavorite;

  String get lanName => 'HostConnect - $name';

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? isFavorite,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
