import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/macos_app_importer.dart';

/// Result of the application picker: a chosen installed app, or a request to
/// enter a program manually. `null` (from showDialog) means cancelled.
class AppPickResult {
  const AppPickResult.selected(this.app) : manual = false;
  const AppPickResult.manual()
      : app = null,
        manual = true;

  final InstalledApp? app;
  final bool manual;
}

/// Shows a searchable list of installed macOS applications. Returns the chosen
/// app, a manual-entry request, or null if cancelled.
Future<AppPickResult?> showApplicationPickerDialog(BuildContext context) {
  return showDialog<AppPickResult>(
    context: context,
    builder: (_) => const _ApplicationPickerDialog(),
  );
}

class _ApplicationPickerDialog extends StatefulWidget {
  const _ApplicationPickerDialog();

  @override
  State<_ApplicationPickerDialog> createState() => _ApplicationPickerDialogState();
}

class _ApplicationPickerDialogState extends State<_ApplicationPickerDialog> {
  late final List<InstalledApp> _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = const MacAppImporter().listInstalledApps();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? _all
        : _all.where((a) => a.name.toLowerCase().contains(q)).toList();

    return AlertDialog(
      title: Text(l10n.selectApplication),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchAppName,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            // Manual entry pinned at the top.
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.addManual),
              onTap: () => Navigator.pop(context, const AppPickResult.manual()),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(l10n.noSearchResults))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final app = items[i];
                        return ListTile(
                          leading: _AppIconThumb(appPath: app.path),
                          title: Text(app.name),
                          subtitle: Text(
                            app.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () =>
                              Navigator.pop(context, AppPickResult.selected(app)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// Lazily loads and shows a small app-icon thumbnail; falls back to a generic
/// icon while loading or if extraction fails. Extraction is cached in the
/// importer, so re-displaying the same app on scroll is cheap.
class _AppIconThumb extends StatefulWidget {
  const _AppIconThumb({required this.appPath});

  final String appPath;

  @override
  State<_AppIconThumb> createState() => _AppIconThumbState();
}

class _AppIconThumbState extends State<_AppIconThumb> {
  String? _png;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final png = await const MacAppImporter().iconPreviewPng(widget.appPath);
    if (mounted) setState(() => _png = png);
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    if (png != null && File(png).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(png), width: 32, height: 32, fit: BoxFit.cover),
      );
    }
    return const SizedBox(
      width: 32,
      height: 32,
      child: Icon(Icons.apps),
    );
  }
}
