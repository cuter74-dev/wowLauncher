import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/app_localizations.dart';
import '../services/macos_app_importer.dart';
import '../state/providers.dart';
import 'app_edit_dialog.dart';
import 'application_picker_dialog.dart';

/// Manages the list of registered apps: add / edit / delete / test / toggle.
class AppsTab extends ConsumerWidget {
  const AppsTab({super.key});

  /// Opens the application picker. Choosing an app registers it in one step
  /// (auto name/path/icon); choosing "manual entry" opens the edit dialog.
  Future<void> _addFromApplication(BuildContext context, WidgetRef ref) async {
    final result = await showApplicationPickerDialog(context);
    if (result == null || !context.mounted) return;

    if (result.manual) {
      await showAppEditDialog(context, ref, null);
      return;
    }

    final imported = await const MacAppImporter().extractFrom(result.app!.path);
    final now = DateTime.now();
    final app = LaunchApp(
      id: const Uuid().v4(),
      name: imported.name,
      executablePath: imported.executablePath,
      iconPath: imported.iconPath,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(appsProvider.notifier).save(app);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.registered(imported.name))),
    );
  }

  Future<void> _testRun(BuildContext context, WidgetRef ref, LaunchApp app) async {
    final launcher = ref.read(servicesProvider).launcher;
    final result = await launcher.launch(app);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? l10n.launched(app.name) : l10n.launchFailedWith(result.message)),
        backgroundColor: result.ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, LaunchApp app) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteApp),
        content: Text(l10n.deleteAppConfirm(app.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appsProvider.notifier).delete(app.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(appsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      floatingActionButton: const MacAppImporter().isSupported
          ? FloatingActionButton.extended(
              onPressed: () => _addFromApplication(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.addFromApplication),
            )
          : FloatingActionButton.extended(
              onPressed: () => showAppEditDialog(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.addManual),
            ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (apps) {
          if (apps.isEmpty) {
            return Center(
              child: Text(l10n.noApps, textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final app = apps[i];
              return ListTile(
                leading: _AppIcon(iconPath: app.iconPath),
                title: Text(app.name),
                subtitle: Text(
                  app.executablePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mobile visibility toggle.
                    Tooltip(
                      message: l10n.mobileVisible,
                      child: Switch(
                        value: app.enabled,
                        onChanged: (_) =>
                            ref.read(appsProvider.notifier).toggleEnabled(app),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.testRun,
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _testRun(context, ref, app),
                    ),
                    IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showAppEditDialog(context, ref, app),
                    ),
                    IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, app),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.iconPath});
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    final path = iconPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(path), width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return const CircleAvatar(child: Icon(Icons.apps));
  }
}
