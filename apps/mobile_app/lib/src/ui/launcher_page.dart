import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../l10n/app_localizations.dart';
import '../api/agent_client.dart';
import '../models/pc_connection.dart';
import '../state/providers.dart';

/// Grid of launchable app icons for a single PC.
class LauncherPage extends ConsumerWidget {
  const LauncherPage({super.key, required this.pc});

  final PcConnection pc;

  Future<void> _launch(BuildContext context, WidgetRef ref, AppListItem app) async {
    final l10n = AppLocalizations.of(context);
    final client = ref.read(agentClientProvider);
    try {
      final res = await client.launch(pc, app.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.ok ? l10n.launched(app.name) : l10n.launchFailedWith(res.message)),
          backgroundColor: res.ok ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    } on AgentApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appsAsync = ref.watch(appsForPcProvider(pc));

    return Scaffold(
      appBar: AppBar(
        title: Text(pc.agentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(appsForPcProvider(pc)),
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(appsForPcProvider(pc)),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return Center(child: Text(l10n.noAppsToShow, textAlign: TextAlign.center));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(appsForPcProvider(pc)),
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.85,
              ),
              itemCount: apps.length,
              itemBuilder: (context, i) {
                final app = apps[i];
                return _AppTile(app: app, onTap: () => _launch(context, ref, app));
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onTap});

  final AppListItem app;
  final VoidCallback onTap;

  Uint8List? _decodeIcon() {
    final b64 = app.iconBase64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeIcon();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : const Icon(Icons.apps, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            app.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
