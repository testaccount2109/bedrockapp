import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/server_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/local_database.dart';

final localDatabaseProvider = FutureProvider<LocalDatabase>((ref) async {
  final database = await LocalDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final serverRepositoryProvider = FutureProvider<ServerRepository>((ref) async {
  return ref.watch(localDatabaseProvider.future);
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((ref) async {
  return ref.watch(localDatabaseProvider.future);
});
