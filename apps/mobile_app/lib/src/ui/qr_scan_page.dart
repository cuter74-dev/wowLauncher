import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/app_localizations.dart';
import '../api/agent_client.dart';
import '../models/pc_connection.dart';
import '../state/providers.dart';

/// Scans a pairing QR and walks through the approval handshake.
class QrScanPage extends ConsumerStatefulWidget {
  const QrScanPage({super.key});

  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

enum _Phase { scanning, pairing, error }

class _QrScanPageState extends ConsumerState<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  _Phase _phase = _Phase.scanning;
  String _status = '';
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _deviceType => Platform.isIOS ? 'ios' : 'android';
  String get _deviceName => Platform.isIOS ? 'iPhone' : 'Android phone';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final payload = PairingPayload.tryDecode(raw);
    if (payload == null) return; // not one of our QR codes; keep scanning

    _handled = true;
    await _controller.stop();
    await _runPairing(payload);
  }

  Future<void> _runPairing(PairingPayload payload) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phase = _Phase.pairing;
      _status = l10n.pairingRequesting;
    });

    final client = ref.read(agentClientProvider);
    final baseUrl = 'http://${payload.host}:${payload.port}';

    try {
      final reqRes = await client.requestPair(
        baseUrl,
        PairRequest(
          pairingCode: payload.pairingCode,
          deviceName: _deviceName,
          deviceType: _deviceType,
        ),
      );

      if (!mounted) return;
      setState(() => _status = l10n.waitingApproval);

      // Poll for approval (up to ~60s).
      const maxTries = 40;
      for (var i = 0; i < maxTries; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        final status = await client.pairStatus(baseUrl, reqRes.requestId);
        if (status.status == PairStatus.approved && status.accessToken != null) {
          await _onApproved(payload, status.accessToken!);
          return;
        }
        if (status.status == PairStatus.rejected) {
          _fail(l10n.pairRejected);
          return;
        }
      }
      _fail(l10n.pairTimeout);
    } on AgentApiException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(l10n.pairErrorWith(e));
    }
  }

  Future<void> _onApproved(PairingPayload payload, String token) async {
    final l10n = AppLocalizations.of(context);
    // Try to read the platform name (best effort).
    String platform = '';
    try {
      final health = await ref.read(agentClientProvider).health(
            'http://${payload.host}:${payload.port}',
          );
      platform = health.platform;
    } catch (_) {}

    final pc = PcConnection(
      id: const Uuid().v4(),
      agentName: payload.agentName,
      host: payload.host,
      port: payload.port,
      accessToken: token,
      platform: platform,
      addedAt: DateTime.now(),
      lastConnectedAt: DateTime.now(),
    );
    await ref.read(pcsProvider.notifier).add(pc);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.connectedTo(payload.agentName))),
    );
    Navigator.of(context).pop();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _status = message;
    });
  }

  void _retry() {
    _handled = false;
    setState(() {
      _phase = _Phase.scanning;
      _status = '';
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanQr)),
      body: switch (_phase) {
        _Phase.scanning => Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              // Simple reticle overlay.
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Positioned(
                bottom: 48,
                child: Text(
                  l10n.pointAtQr,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        _Phase.pairing => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_status),
              ],
            ),
          ),
        _Phase.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_status, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _retry, child: Text(l10n.scanAgain)),
                ],
              ),
            ),
          ),
      },
    );
  }
}
