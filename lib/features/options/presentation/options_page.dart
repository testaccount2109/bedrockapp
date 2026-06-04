import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/localization/localization_providers.dart';

class OptionsPage extends ConsumerWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final selectedLanguage = settings.valueOrNull?.languageCode ?? 'de';

    return Scaffold(
      appBar: AppBar(title: Text(strings.optionsTab)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.language,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'de',
                          label: Text(strings.german),
                        ),
                        ButtonSegment<String>(
                          value: 'en',
                          label: Text(strings.english),
                        ),
                      ],
                      selected: <String>{
                        AppStrings.supportedLanguageCodes
                                .contains(selectedLanguage)
                            ? selectedLanguage
                            : 'de',
                      },
                      onSelectionChanged: (selection) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setLanguage(selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
