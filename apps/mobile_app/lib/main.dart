import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'l10n/app_localizations.dart';
import 'src/db/mobile_database.dart';
import 'src/state/providers.dart';
import 'src/ui/pc_list_page.dart';

/// GlitchTip (Sentry-compatible) DSN, injected at build time:
/// `--dart-define=GLITCHTIP_DSN=...`. Empty → error tracking disabled.
const _glitchtipDsn = String.fromEnvironment('GLITCHTIP_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await MobileDatabase.open();
  final lang = await db.getLanguage();

  final app = ProviderScope(
    overrides: [
      mobileDbProvider.overrideWithValue(db),
      initialLocaleProvider.overrideWithValue(lang == null ? null : Locale(lang)),
    ],
    child: const MobileApp(),
  );

  if (_glitchtipDsn.isEmpty) {
    runApp(app);
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _glitchtipDsn;
        options.environment = 'mobile';
        options.release = 'wowlauncher-mobile@0.1.0';
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(app),
    );
  }
}

class MobileApp extends ConsumerWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'wowLauncher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22D3EE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PcListPage(),
    );
  }
}
