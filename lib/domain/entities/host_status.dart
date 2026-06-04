enum HostRunState {
  offline,
  starting,
  online,
  stopping,
  failed,
}

class HostStatus {
  const HostStatus({
    required this.state,
    required this.activeServerName,
    required this.activeServerHost,
    required this.activeServerPort,
    required this.transferCount,
    required this.startedAt,
    required this.lastError,
  });

  final HostRunState state;
  final String? activeServerName;
  final String? activeServerHost;
  final int? activeServerPort;
  final int transferCount;
  final DateTime? startedAt;
  final String? lastError;

  bool get isOnline => state == HostRunState.online;

  static const offline = HostStatus(
    state: HostRunState.offline,
    activeServerName: null,
    activeServerHost: null,
    activeServerPort: null,
    transferCount: 0,
    startedAt: null,
    lastError: null,
  );

  HostStatus copyWith({
    HostRunState? state,
    String? activeServerName,
    String? activeServerHost,
    int? activeServerPort,
    int? transferCount,
    DateTime? startedAt,
    String? lastError,
    bool clearError = false,
    bool clearStartedAt = false,
  }) {
    return HostStatus(
      state: state ?? this.state,
      activeServerName: activeServerName ?? this.activeServerName,
      activeServerHost: activeServerHost ?? this.activeServerHost,
      activeServerPort: activeServerPort ?? this.activeServerPort,
      transferCount: transferCount ?? this.transferCount,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}
