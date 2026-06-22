import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
            l10n.newDeviceRequest(req.deviceName, req.deviceType),
          ),
          actions: [
            TextButton(
              onPressed: () => pairing.reject(req.requestId),
              child: Text(l10n.reject),
            ),
            FilledButton(
              onPressed: () async {
                await pairing.approve(req.requestId, now: DateTime.now());
                // Refresh the device list so the new device shows up.
                ref.invalidate(devicesProvider);
              },
              child: Text(l10n.approve),
            ),
          ],
        );
      },
    );
  }
}
