import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../state/providers.dart';

/// Lists paired mobile devices with block / delete actions.
class DevicesTab extends ConsumerWidget {
  const DevicesTab({super.key});

  String _formatTime(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('연결된 기기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(devicesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('연결된 기기가 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final PairedDevice d = devices[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: d.blocked ? Colors.red.shade100 : null,
                  child: Icon(
                    d.deviceType == 'ios' ? Icons.phone_iphone : Icons.phone_android,
                  ),
                ),
                title: Text(d.deviceName),
                subtitle: Text(
                  '마지막 접속: ${_formatTime(d.lastSeenAt)}'
                  '${d.blocked ? '  ·  차단됨' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: d.blocked ? '차단 해제' : '차단',
                      icon: Icon(d.blocked ? Icons.lock_open : Icons.block),
                      onPressed: () => ref
                          .read(devicesProvider.notifier)
                          .setBlocked(d.id, !d.blocked),
                    ),
                    IconButton(
                      tooltip: '삭제',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(devicesProvider.notifier).delete(d.id),
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
