import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../../../data/providers/data_providers.dart';
import '../../../domain/entities/server_profile.dart';

final serverListControllerProvider =
    AsyncNotifierProvider<ServerListController, List<ServerProfile>>(
  ServerListController.new,
);

class ServerListController extends AsyncNotifier<List<ServerProfile>> {
  final IdGenerator _idGenerator = const IdGenerator();

  @override
  Future<List<ServerProfile>> build() async {
    final repository = await ref.watch(serverRepositoryProvider.future);
    return repository.listProfiles();
  }

  Future<void> save({
    String? id,
    required String name,
    required String host,
    required int port,
    required bool isFavorite,
  }) async {
    final repository = await ref.read(serverRepositoryProvider.future);
    final profile = ServerProfile(
      id: id ?? _idGenerator.create(),
      name: name.trim(),
      host: host.trim(),
      port: port,
      isFavorite: isFavorite,
    );
    await repository.saveProfile(profile);
    state = AsyncData<List<ServerProfile>>(await repository.listProfiles());
  }

  Future<void> delete(String id) async {
    final repository = await ref.read(serverRepositoryProvider.future);
    await repository.deleteProfile(id);
    state = AsyncData<List<ServerProfile>>(await repository.listProfiles());
  }

  Future<void> setFavorite(ServerProfile profile, bool isFavorite) async {
    final repository = await ref.read(serverRepositoryProvider.future);
    await repository.saveProfile(profile.copyWith(isFavorite: isFavorite));
    state = AsyncData<List<ServerProfile>>(await repository.listProfiles());
  }
}
