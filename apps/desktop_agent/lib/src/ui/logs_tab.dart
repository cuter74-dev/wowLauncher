import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../state/providers.dart';

/// Recent launch audit logs.
class LogsTab extends ConsumerWidget {
  const LogsTab({super.key});

  String _formatTime(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(logsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.launchLogs),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(logsProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: l10n.clearLogs,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => ref.read(logsProvider.notifier).clear(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith(e))),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(child: Text(l10n.noLogs));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final log = logs[i];
              return ListTile(
                leading: Icon(
                  log.success ? Icons.check_circle : Icons.error,
                  color: log.success ? Colors.green : Colors.red,
                ),
                title: Text('${log.appName}  ·  ${log.deviceName}'),
                subtitle: Text(
                  '${_formatTime(log.timestamp)}'
                  '${log.message.isNotEmpty ? '\n${log.message}' : ''}',
                ),
                isThreeLine: log.message.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
