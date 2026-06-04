import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/localization_providers.dart';
import '../../../domain/entities/server_profile.dart';
import '../application/server_list_controller.dart';

class ServerFormSheet extends ConsumerStatefulWidget {
  const ServerFormSheet({super.key, this.profile});

  final ServerProfile? profile;

  @override
  ConsumerState<ServerFormSheet> createState() => _ServerFormSheetState();
}

class _ServerFormSheetState extends ConsumerState<ServerFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _hostController = TextEditingController(text: profile?.host ?? '');
    _portController = TextEditingController(
      text: (profile?.port ?? 19132).toString(),
    );
    _isFavorite = profile?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.profile == null
                        ? strings.addServer
                        : strings.editServer,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: strings.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: strings.name,
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
              validator: (value) => _required(value, strings.requiredField),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: strings.address,
                prefixIcon: const Icon(Icons.public_outlined),
              ),
              validator: (value) => _required(value, strings.requiredField),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.port,
                prefixIcon: const Icon(Icons.settings_ethernet_outlined),
              ),
              validator: (value) {
                final port = int.tryParse(value ?? '');
                if (port == null || port < 1 || port > 65535) {
                  return strings.invalidPort;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.favorite),
              value: _isFavorite,
              onChanged: (value) => setState(() => _isFavorite = value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(serverListControllerProvider.notifier).save(
          id: widget.profile?.id,
          name: _nameController.text,
          host: _hostController.text,
          port: int.parse(_portController.text),
          isFavorite: _isFavorite,
        );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
