import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../state/providers.dart';

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
            id: Uuid().v4(),
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
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? '프로그램 수정' : '프로그램 추가'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '앱 이름 *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '이름을 입력하세요.' : null,
                ),
                TextFormField(
                  controller: _exec,
                  decoration: InputDecoration(
                    labelText: '실행 파일 경로 *',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickExecutable,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '실행 파일 경로를 입력하세요.' : null,
                ),
                TextFormField(
                  controller: _args,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '실행 인자 (선택)',
                    helperText: '한 줄에 하나씩 입력하세요.',
                  ),
                ),
                TextFormField(
                  controller: _workingDir,
                  decoration: InputDecoration(
                    labelText: '작업 폴더 (선택)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickWorkingDir,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _iconPath,
                  decoration: InputDecoration(
                    labelText: '아이콘 이미지 경로 (선택)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickIcon,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('모바일에 표시'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}
