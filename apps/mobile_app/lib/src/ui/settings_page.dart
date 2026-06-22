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

/// Settings screen: currently the UI language picker.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentCode = Localizations.localeOf(context).languageCode;
    final selected =
        supportedLanguages.any((l) => l.code == currentCode) ? currentCode : 'en';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 8),
                Text(l10n.language,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          for (final lang in supportedLanguages)
            ListTile(
              title: Text(lang.label),
              trailing: lang.code == selected ? const Icon(Icons.check) : null,
              onTap: () => ref.read(localeProvider.notifier).setLanguage(lang.code),
            ),
        ],
      ),
    );
  }
}
