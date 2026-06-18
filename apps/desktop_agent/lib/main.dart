import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/state/providers.dart';
import 'src/ui/home_page.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
      ],
      child: const DesktopAgentApp(),
    ),
  );
}

class DesktopAgentApp extends StatelessWidget {
  const DesktopAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Launcher Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
