import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pairing_service.dart';
import '../state/providers.dart';

/// A banner shown whenever a mobile device is waiting for pairing approval.
///
/// Listens to [PairingService] (a [ChangeNotifier]) via [ListenableBuilder].
class PairingBanner extends ConsumerWidget {
  const PairingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PairingService pairing = ref.watch(pairingServiceProvider);
    return ListenableBuilder(
      listenable: pairing,
      builder: (context, _) {
        final pending = pairing.pendingRequests;
        if (pending.isEmpty) return const SizedBox.shrink();
        final req = pending.first;
        return MaterialBanner(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          leading: const Icon(Icons.phonelink_ring),
          content: Text(
            '새 기기 연결 요청: "${req.deviceName}" (${req.deviceType})',
          ),
          actions: [
            TextButton(
              onPressed: () => pairing.reject(req.requestId),
              child: const Text('거부'),
            ),
            FilledButton(
              onPressed: () async {
                await pairing.approve(req.requestId, now: DateTime.now());
                // Refresh the device list so the new device shows up.
                ref.invalidate(devicesProvider);
              },
              child: const Text('승인'),
            ),
          ],
        );
      },
    );
  }
}
