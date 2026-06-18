import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Settings: agent name, server port, and start/stop controls.
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  late final TextEditingController _name;
  late final TextEditingController _port;

  @override
  void initState() {
    super.initState();
    final services = ref.read(servicesProvider);
    _name = TextEditingController(text: services.agentName);
    _port = TextEditingController(text: ref.read(serverProvider).port.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final services = ref.read(servicesProvider);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await services.settings.setAgentName(name);
    services.agentName = name;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PC 이름을 저장했습니다.')));
      setState(() {});
    }
  }

  Future<void> _applyPort() async {
    final services = ref.read(servicesProvider);
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1024~65535 사이의 포트를 입력하세요.')),
      );
      return;
    }
    await services.settings.setPort(port);
    try {
      await ref.read(serverProvider.notifier).restart(port);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('포트 $port 에서 재시작했습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('서버 재시작 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(serverProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'PC 이름',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveName,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '서버 포트',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _applyPort,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: server.running
                          ? () => ref.read(serverProvider.notifier).stop()
                          : () => ref.read(serverProvider.notifier).startWith(server.port),
                      icon: Icon(server.running ? Icons.stop : Icons.play_arrow),
                      label: Text(server.running ? '서버 중지' : '서버 시작'),
                    ),
                    const SizedBox(width: 12),
                    Text(server.running ? '실행 중 (:${server.port})' : '중지됨'),
                  ],
                ),
                const SizedBox(height: 32),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, size: 20),
                            SizedBox(width: 8),
                            Text('보안 안내',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 이 에이전트는 같은 LAN(와이파이)에서만 사용하세요.\n'
                          '• 공인 인터넷에 포트를 노출하지 마세요.\n'
                          '• 모바일은 등록된 앱만 실행할 수 있으며, 임의 명령은 실행되지 않습니다.\n'
                          '• 외부 접속이 필요하면 Tailscale/VPN 사용을 권장합니다.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
