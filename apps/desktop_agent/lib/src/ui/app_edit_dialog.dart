import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/app_localizations.dart';
import '../services/macos_app_importer.dart';
import '../state/providers.dart';
import 'application_picker_dialog.dart';

/// Opens the add/edit dialog. Pass null [existing] to create a new app.
Future<void> showAppEditDialog(BuildContext context, WidgetRef ref, LaunchApp? existing) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AppEditDialog(existing: existing),
  );
}

class _AppEditDialog extends ConsumerStatefulWidget {
  const _AppEditDialog({this.existing});
  final LaunchApp? existing;

  @override
  ConsumerState<_AppEditDialog> createState() => _AppEditDialogState();
}

class _AppEditDialogState extends ConsumerState<_AppEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _exec;
  late final TextEditingController _args;
  late final TextEditingController _workingDir;
  late final TextEditingController _iconPath;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _exec = TextEditingController(text: e?.executablePath ?? '');
    // One argument per line keeps things unambiguous (no shell splitting).
    _args = TextEditingController(text: (e?.arguments ?? const <String>[]).join('\n'));
    _workingDir = TextEditingController(text: e?.workingDirectory ?? '');
    _iconPath = TextEditingController(text: e?.iconPath ?? '');
    _enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _exec.dispose();
    _args.dispose();
    _workingDir.dispose();
    _iconPath.dispose();
    super.dispose();
  }

  Future<void> _pickExecutable() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _exec.text = result.files.single.path!);
    }
  }

  Future<void> _pickWorkingDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) setState(() => _workingDir.text = dir);
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _iconPath.text = result.files.single.path!);
    }
  }

  /// Pick an installed macOS app and auto-fill name / path / icon.
  Future<void> _pickApplication() async {
    final selected = await showApplicationPickerDialog(context);
    if (selected == null) return;
    final imp = await const MacAppImporter().extractFrom(selected.path);
    if (!mounted) return;
    setState(() {
      _name.text = imp.name;
      _exec.text = imp.executablePath;
      if (imp.iconPath != null) _iconPath.text = imp.iconPath!;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final args = _args.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final existing = widget.existing;
    final app = existing == null
        ? LaunchApp(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            executablePath: _exec.text.trim(),
            arguments: args,
            workingDirectory: _emptyToNull(_workingDir.text),
            iconPath: _emptyToNull(_iconPath.text),
            enabled: _enabled,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: _name.text.trim(),
            executablePath: _exec.text.trim(),
            arguments: args,
            workingDirectory: _emptyToNull(_workingDir.text),
            clearWorkingDirectory: _workingDir.text.trim().isEmpty,
            iconPath: _emptyToNull(_iconPath.text),
            clearIconPath: _iconPath.text.trim().isEmpty,
            enabled: _enabled,
            updatedAt: now,
          );

    await ref.read(appsProvider.notifier).save(app);
    if (mounted) Navigator.of(context).pop();
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? l10n.editProgram : l10n.addProgram),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (const MacAppImporter().isSupported) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _pickApplication,
                      icon: const Icon(Icons.apps),
                      label: Text(l10n.importFromApplication),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.appNameRequired),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.enterName : null,
                ),
                TextFormField(
                  controller: _exec,
                  decoration: InputDecoration(
                    labelText: l10n.execPathRequired,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickExecutable,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.enterExecPath : null,
                ),
                TextFormField(
                  controller: _args,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.launchArgsOptional,
                    helperText: l10n.oneArgPerLine,
                  ),
                ),
                TextFormField(
                  controller: _workingDir,
                  decoration: InputDecoration(
                    labelText: l10n.workingDirOptional,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickWorkingDir,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _iconPath,
                  decoration: InputDecoration(
                    labelText: l10n.iconImagePathOptional,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickIcon,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.showOnMobileField),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
