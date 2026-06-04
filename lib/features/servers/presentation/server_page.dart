import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/localization/localization_providers.dart';
import '../../../core/logging/log_event.dart';
import '../../../core/logging/log_level.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/entities/host_status.dart';
import '../../../domain/entities/server_profile.dart';
import '../../../services/providers/service_providers.dart';
import '../application/host_actions_controller.dart';
import '../application/server_list_controller.dart';
import 'server_form_sheet.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final servers = ref.watch(serverListControllerProvider);
    final status = ref.watch(hostStatusProvider).valueOrNull ?? HostStatus.offline;
    final logs = ref.watch(logEventsProvider).valueOrNull ?? const <LogEvent>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.serversTab),
        actions: <Widget>[
          IconButton(
            tooltip: strings.addServer,
            onPressed: () => _openForm(context, strings),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: servers.when(
          data: (profiles) => _buildContent(
            context: context,
            strings: strings,
            profiles: profiles,
            status: status,
            logs: logs,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: strings.addServer,
        onPressed: () => _openForm(context, strings),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AppStrings strings,
    required List<ServerProfile> profiles,
    required HostStatus status,
    required List<LogEvent> logs,
  }) {
    final filtered = profiles.where((profile) {
      final needle = _query.trim().toLowerCase();
      if (needle.isEmpty) {
        return true;
      }
      return profile.name.toLowerCase().contains(needle) ||
          profile.host.toLowerCase().contains(needle) ||
          profile.port.toString().contains(needle);
    }).toList();

    final favorites =
        filtered.where((profile) => profile.isFavorite).toList(growable: false);
    final regular =
        filtered.where((profile) => !profile.isFavorite).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: <Widget>[
        _HostStatusCard(status: status, strings: strings),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: strings.search,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: strings.cancel,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (profiles.isEmpty)
          _EmptyState(text: strings.noServers)
        else if (filtered.isEmpty)
          _EmptyState(text: strings.noSearchResults)
        else ...<Widget>[
          if (favorites.isNotEmpty) ...<Widget>[
            _SectionTitle(title: strings.favorites),
            const SizedBox(height: 8),
            for (final profile in favorites)
              _ServerCard(
                profile: profile,
                status: status,
                strings: strings,
                onStart: () => _startHost(profile),
                onEdit: () => _openForm(context, strings, profile: profile),
                onDelete: () => _confirmDelete(context, strings, profile),
                onFavoriteChanged: (value) => ref
                    .read(serverListControllerProvider.notifier)
                    .setFavorite(profile, value),
              ),
            const SizedBox(height: 12),
          ],
          _SectionTitle(title: strings.allServers),
          const SizedBox(height: 8),
          for (final profile in regular)
            _ServerCard(
              profile: profile,
              status: status,
              strings: strings,
              onStart: () => _startHost(profile),
              onEdit: () => _openForm(context, strings, profile: profile),
              onDelete: () => _confirmDelete(context, strings, profile),
              onFavoriteChanged: (value) => ref
                  .read(serverListControllerProvider.notifier)
                  .setFavorite(profile, value),
            ),
        ],
        const SizedBox(height: 12),
        _LogPanel(events: logs, strings: strings),
      ],
    );
  }

  Future<void> _startHost(ServerProfile profile) async {
    await ref.read(hostActionsControllerProvider).start(profile);
  }

  Future<void> _openForm(
    BuildContext context,
    AppStrings strings, {
    ServerProfile? profile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ServerFormSheet(profile: profile),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStrings strings,
    ServerProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteServer),
        content: Text(strings.confirmDelete),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.deleteServer),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(serverListControllerProvider.notifier).delete(profile.id);
    }
  }
}

class _HostStatusCard extends ConsumerWidget {
  const _HostStatusCard({required this.status, required this.strings});

  final HostStatus status;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (status.state) {
      HostRunState.online => Colors.greenAccent,
      HostRunState.failed => Colors.redAccent,
      HostRunState.starting || HostRunState.stopping => Colors.amberAccent,
      HostRunState.offline => Colors.white60,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 8),
                Text(
                  '${strings.onlineStatus}: ${strings.statusLabel(status.state)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (status.state == HostRunState.online ||
                    status.state == HostRunState.starting)
                  IconButton(
                    tooltip: strings.stopHost,
                    onPressed: () =>
                        ref.read(hostActionsControllerProvider).stop(),
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: strings.activeServer,
              value: status.activeServerName ?? '-',
            ),
            _InfoRow(
              label: strings.transfers,
              value: status.transferCount.toString(),
            ),
            if (status.lastError != null)
              _InfoRow(label: 'Error', value: status.lastError!),
          ],
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.profile,
    required this.status,
    required this.strings,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    required this.onFavoriteChanged,
  });

  final ServerProfile profile;
  final HostStatus status;
  final AppStrings strings;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = status.state == HostRunState.online &&
        status.activeServerName == profile.name &&
        status.activeServerHost == profile.host &&
        status.activeServerPort == profile.port;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  tooltip: strings.favorite,
                  onPressed: () => onFavoriteChanged(!profile.isFavorite),
                  icon: Icon(
                    profile.isFavorite ? Icons.star : Icons.star_border,
                    color: profile.isFavorite ? Colors.amberAccent : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${profile.host}:${profile.port}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<_ServerMenuAction>(
                  tooltip: 'Menu',
                  onSelected: (action) {
                    switch (action) {
                      case _ServerMenuAction.edit:
                        onEdit();
                        break;
                      case _ServerMenuAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<_ServerMenuAction>>[
                    PopupMenuItem<_ServerMenuAction>(
                      value: _ServerMenuAction.edit,
                      child: Text(strings.editServer),
                    ),
                    PopupMenuItem<_ServerMenuAction>(
                      value: _ServerMenuAction.delete,
                      child: Text(strings.deleteServer),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: Icon(isActive ? Icons.check_circle : Icons.play_arrow),
                label: Text(isActive ? strings.activeServer : strings.startHost),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.events, required this.strings});

  final List<LogEvent> events;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final visible = events.reversed.take(60).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.logs, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Text(strings.noLogs)
            else
              for (final event in visible) _LogLine(event: event),
          ],
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.event});

  final LogEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.level) {
      LogLevel.debug => Colors.white54,
      LogLevel.info => Colors.lightBlueAccent,
      LogLevel.warning => Colors.amberAccent,
      LogLevel.error => Colors.redAccent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '[${event.category}] ${event.message}${_details(event)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _details(LogEvent event) {
    if (event.details.isEmpty) {
      return '';
    }
    final text = event.details.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    return text.isEmpty ? '' : ' ($text)';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text)),
      ),
    );
  }
}

enum _ServerMenuAction {
  edit,
  delete,
}
