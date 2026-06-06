import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/localization_providers.dart';
import '../../../domain/entities/server_profile.dart';
import '../../../services/providers/service_providers.dart';

final hostActionsControllerProvider = Provider<HostActionsController>((ref) {
  return HostActionsController(ref);
});

class HostActionsController {
  HostActionsController(this._ref);

  final Ref _ref;

  Future<void> start(ServerProfile profile) async {
    final settings = await _ref.read(settingsControllerProvider.future);
    await _ref.read(hostSessionManagerProvider).start(
          server: profile,
          serverGuid: settings.localServerGuid,
        );
  }

  Future<void> stop() {
    return _ref.read(hostSessionManagerProvider).stop();
  }
}
