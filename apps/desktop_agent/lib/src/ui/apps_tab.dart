import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../state/providers.dart';
import 'app_edit_dialog.dart';

/// Manages the list of registered apps: add / edit / delete / test / toggle.
class AppsTab extends ConsumerWidget {
  const AppsTab({super.key});

  Future<void> _testRun(BuildContext context, WidgetRef ref, LaunchApp app) async {
    final launcher = ref.read(servicesProvider).launcher;
    final result = await launcher.launch(app);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? '실행됨: ${app.name}' : '실패: ${result.message}'),
        backgroundColor: result.ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, LaunchApp app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('앱 삭제'),
        content: Text('"${app.name}" 앱을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAppEditDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('프로그램 추가'),
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (apps) {
          if (apps.isEmpty) {
            return const Center(
              child: Text('등록된 프로그램이 없습니다.\n오른쪽 아래 버튼으로 추가하세요.',
                  textAlign: TextAlign.center),
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
                      message: '모바일 표시',
                      child: Switch(
                        value: app.enabled,
                        onChanged: (_) =>
                            ref.read(appsProvider.notifier).toggleEnabled(app),
                      ),
                    ),
                    IconButton(
                      tooltip: '테스트 실행',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _testRun(context, ref, app),
                    ),
                    IconButton(
                      tooltip: '수정',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showAppEditDialog(context, ref, app),
                    ),
                    IconButton(
                      tooltip: '삭제',
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
