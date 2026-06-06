import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/shell/presentation/home_shell.dart';
import 'localization/localization_providers.dart';
import 'app_theme.dart';

class HostConnectApp extends ConsumerWidget {
  const HostConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.appTitle,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
