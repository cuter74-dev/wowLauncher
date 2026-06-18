import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
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

  static const _destinations = <({IconData icon, String label})>[
    (icon: Icons.dashboard_outlined, label: 'Status'),
    (icon: Icons.apps_outlined, label: 'Apps'),
    (icon: Icons.devices_outlined, label: 'Devices'),
    (icon: Icons.receipt_long_outlined, label: 'Logs'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
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
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.rocket_launch, size: 28),
            ),
            destinations: [
              for (final d in _destinations)
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
