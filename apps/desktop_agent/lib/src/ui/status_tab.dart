import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';

import '../state/providers.dart';

/// Main status screen: agent state, PC name, port, LAN IPs and pairing QR.
class StatusTab extends ConsumerWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverProvider);
    final netAsync = ref.watch(networkInfoProvider);
    final pairing = ref.watch(pairingServiceProvider);
    final agentName = ref.watch(servicesProvider).agentName;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              // Left: status info card.
              SizedBox(
                width: 380,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusRow(
                          icon: server.running ? Icons.check_circle : Icons.cancel,
                          color: server.running ? Colors.green : Colors.red,
                          label: 'Agent',
                          value: server.running ? '실행 중' : '중지됨',
                        ),
                        const Divider(),
                        _StatusRow(
                          icon: Icons.computer,
                          label: 'PC 이름',
                          value: agentName,
                        ),
                        const Divider(),
                        _StatusRow(
                          icon: Icons.lan,
                          label: '포트',
                          value: '${server.port}',
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('사용 가능한 IP 주소',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        netAsync.when(
                          data: (info) => info.ips.isEmpty
                              ? const Text('네트워크 주소를 찾을 수 없습니다.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final ip in info.ips)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: SelectableText('$ip:${server.port}'),
                                      ),
                                  ],
                                ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('오류: $e'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => ref.invalidate(networkInfoProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('IP 새로고침'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Right: pairing QR code.
              SizedBox(
                width: 320,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('모바일 페어링',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        netAsync.when(
                          data: (info) {
                            final host = info.ips.isNotEmpty ? info.ips.first : '0.0.0.0';
                            // Rebuild the QR whenever the pairing code rotates.
                            return ListenableBuilder(
                              listenable: pairing,
                              builder: (context, _) {
                                final payload = PairingPayload(
                                  agentName: agentName,
                                  host: host,
                                  port: server.port,
                                  pairingCode: pairing.currentCode,
                                );
                                return Column(
                                  children: [
                                    QrImageView(
                                      data: payload.encode(),
                                      size: 220,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 12),
                                    SelectableText('Code: ${pairing.currentCode}'),
                                    const SizedBox(height: 4),
                                    Text('Host: $host:${server.port}',
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                );
                              },
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                          error: (e, _) => Text('오류: $e'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: pairing.rotateCode,
                          icon: const Icon(Icons.autorenew),
                          label: const Text('새 코드 생성'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
