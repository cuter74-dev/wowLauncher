import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'l10n/app_localizations.dart';
import 'src/state/providers.dart';
import 'src/ui/home_page.dart';

/// GlitchTip (Sentry-compatible) DSN, injected at build time:
/// `--dart-define=GLITCHTIP_DSN=...`. Empty → error tracking disabled.
const _glitchtipDsn = String.fromEnvironment('GLITCHTIP_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the DB and wire up all services before the UI starts.
  final services = await AppServices.bootstrap();

  // Auto-start the HTTP server on the saved port so the agent is immediately
  // reachable from the LAN.
  final port = await services.settings.getPort();
  try {
    await services.server.start(port: port);
  } catch (_) {
    // If the port is busy the UI's Settings tab lets the user pick another.
  }

  final app = ProviderScope(
    overrides: [
      servicesProvider.overrideWithValue(services),
    ],
    child: const DesktopAgentApp(),
  );

  if (_glitchtipDsn.isEmpty) {
    runApp(app);
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _glitchtipDsn;
        options.environment = 'desktop';
        options.release = 'wowlauncher-desktop@0.1.0';
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(app),
    );
  }
}

class DesktopAgentApp extends ConsumerWidget {
  const DesktopAgentApp({super.key});

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
      home: const HomePage(),
    );
  }
}
