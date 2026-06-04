import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/data_providers.dart';
import '../../domain/entities/app_settings.dart';
import 'app_strings.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final appStringsProvider = Provider<AppStrings>((ref) {
  final settings = ref.watch(settingsControllerProvider).valueOrNull;
  return AppStrings(settings?.languageCode ?? 'de');
});

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repository = await ref.watch(settingsRepositoryProvider.future);
    return repository.loadSettings();
  }

  Future<void> setLanguage(String languageCode) async {
    final current = state.valueOrNull ?? await future;
    final updated = AppSettings(
      languageCode: languageCode,
      localServerGuid: current.localServerGuid,
    );
    state = AsyncData<AppSettings>(updated);
    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.saveSettings(updated);
  }
}
