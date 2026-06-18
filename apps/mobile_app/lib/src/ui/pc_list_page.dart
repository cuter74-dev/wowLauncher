import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pc_connection.dart';
import '../state/providers.dart';
import 'launcher_page.dart';
import 'qr_scan_page.dart';

/// First screen: list of paired PCs + add-by-QR.
class PcListPage extends ConsumerWidget {
  const PcListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pcsAsync = ref.watch(pcsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 PC')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QrScanPage()),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('PC 추가'),
      ),
      body: pcsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (pcs) {
          if (pcs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '연결된 PC가 없습니다.\n\n아래 "PC 추가" 버튼을 눌러\nPC 화면의 QR 코드를 스캔하세요.',
                  textAlign: TextAlign.center,
                ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PC 삭제'),
        content: Text('"${pc.agentName}" 연결을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(pcsProvider.notifier).remove(pc.id);
    }
  }
}
