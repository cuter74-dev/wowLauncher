import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tabStatus, style: Theme.of(context).textTheme.headlineMedium),
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
                          label: l10n.agent,
                          value: server.running ? l10n.running : l10n.stopped,
                        ),
                        const Divider(),
                        _StatusRow(
                          icon: Icons.computer,
                          label: l10n.pcName,
                          value: agentName,
                        ),
                        const Divider(),
                        _StatusRow(
                          icon: Icons.lan,
                          label: l10n.port,
                          value: '${server.port}',
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(l10n.availableIps,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        netAsync.when(
                          data: (info) => info.ips.isEmpty
                              ? Text(l10n.noNetworkAddress)
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
                          error: (e, _) => Text(l10n.errorWith(e)),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => ref.invalidate(networkInfoProvider),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.refreshIp),
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
                        Text(l10n.mobilePairing,
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
                                    SelectableText(l10n.codeLabel(pairing.currentCode)),
                                    const SizedBox(height: 4),
                                    Text(l10n.hostLabel('$host:${server.port}'),
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
                          error: (e, _) => Text(l10n.errorWith(e)),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: pairing.rotateCode,
                          icon: const Icon(Icons.autorenew),
                          label: Text(l10n.newCode),
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
