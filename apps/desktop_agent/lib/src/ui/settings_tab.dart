import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../state/providers.dart';

/// Selectable UI languages, shown by their native name.
const supportedLanguages = <({String code, String label})>[
  (code: 'en', label: 'English'),
  (code: 'ko', label: '한국어'),
  (code: 'es', label: 'Español'),
  (code: 'zh', label: '中文'),
  (code: 'ja', label: '日本語'),
  (code: 'ru', label: 'Русский'),
  (code: 'fr', label: 'Français'),
  (code: 'de', label: 'Deutsch'),
  (code: 'vi', label: 'Tiếng Việt'),
  (code: 'id', label: 'Indonesia'),
  (code: 'hi', label: 'हिन्दी'),
];

/// Settings: language, agent name, server port, and start/stop controls.
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  late final TextEditingController _name;
  late final TextEditingController _port;

  @override
  void initState() {
    super.initState();
    final services = ref.read(servicesProvider);
    _name = TextEditingController(text: services.agentName);
    _port = TextEditingController(text: ref.read(serverProvider).port.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final l10n = AppLocalizations.of(context);
    final services = ref.read(servicesProvider);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await services.settings.setAgentName(name);
    services.agentName = name;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pcNameSaved)));
      setState(() {});
    }
  }

  Future<void> _applyPort() async {
    final l10n = AppLocalizations.of(context);
    final services = ref.read(servicesProvider);
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.portRange)),
      );
      return;
    }
    await services.settings.setPort(port);
    try {
      await ref.read(serverProvider.notifier).restart(port);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.restartedOnPort(port))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.serverRestartFailed(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final server = ref.watch(serverProvider);

    final currentCode = Localizations.localeOf(context).languageCode;
    final dropdownValue =
        supportedLanguages.any((l) => l.code == currentCode) ? currentCode : 'en';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tabSettings, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: dropdownValue,
                  decoration: InputDecoration(
                    labelText: l10n.language,
                    prefixIcon: const Icon(Icons.language),
                  ),
                  items: [
                    for (final lang in supportedLanguages)
                      DropdownMenuItem(value: lang.code, child: Text(lang.label)),
                  ],
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(localeProvider.notifier).setLanguage(code);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.pcName,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveName,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.serverPort,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _applyPort,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: server.running
                          ? () => ref.read(serverProvider.notifier).stop()
                          : () => ref.read(serverProvider.notifier).startWith(server.port),
                      icon: Icon(server.running ? Icons.stop : Icons.play_arrow),
                      label: Text(server.running ? l10n.stopServer : l10n.startServer),
                    ),
                    const SizedBox(width: 12),
                    Text(server.running ? l10n.serverRunningOn(server.port) : l10n.stopped),
                  ],
                ),
                const SizedBox(height: 32),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.securityNotice,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.securityBody),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
