import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/pc_connection.dart';
import '../state/providers.dart';
import 'launcher_page.dart';
import 'qr_scan_page.dart';
import 'settings_page.dart';

/// First screen: list of paired PCs + add-by-QR.
class PcListPage extends ConsumerWidget {
  const PcListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pcsAsync = ref.watch(pcsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/wow_launcher_logo.png', fit: BoxFit.cover),
          ),
        ),
        title: Text(l10n.myPcs),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QrScanPage()),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(l10n.addPc),
      ),
      body: pcsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith(e))),
        data: (pcs) {
          if (pcs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.noPcs, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: pcs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final PcConnection pc = pcs[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.computer)),
                title: Text(pc.agentName),
                subtitle: Text('${pc.host}:${pc.port}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemove(context, ref, pc),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => LauncherPage(pc: pc)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, PcConnection pc) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePc),
        content: Text(l10n.deletePcConfirm(pc.agentName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(pcsProvider.notifier).remove(pc.id);
    }
  }
}
