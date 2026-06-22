import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'apps_tab.dart';
import 'devices_tab.dart';
import 'logs_tab.dart';
import 'pairing_banner.dart';
import 'settings_tab.dart';
import 'status_tab.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = <({IconData icon, String label})>[
      (icon: Icons.dashboard_outlined, label: l10n.tabStatus),
      (icon: Icons.apps_outlined, label: l10n.tabApps),
      (icon: Icons.devices_outlined, label: l10n.tabDevices),
      (icon: Icons.receipt_long_outlined, label: l10n.tabLogs),
      (icon: Icons.settings_outlined, label: l10n.tabSettings),
    ];
    const pages = <Widget>[
      StatusTab(),
      AppsTab(),
      DevicesTab(),
      LogsTab(),
      SettingsTab(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 900,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/wow_launcher_logo.png',
                    width: 44, height: 44, fit: BoxFit.cover),
              ),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                // Pending pairing requests appear here across all tabs.
                const PairingBanner(),
                Expanded(child: pages[_index]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
