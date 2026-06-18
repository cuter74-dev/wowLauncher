import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('LaunchApp', () {
    test('round-trips through JSON', () {
      final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final app = LaunchApp(
        id: 'abc',
        name: 'VSCode',
        executablePath: '/usr/bin/code',
        arguments: const ['--new-window'],
        workingDirectory: '/home/me',
        iconPath: null,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );
      final decoded = LaunchApp.fromJson(app.toJson());
      expect(decoded.id, app.id);
      expect(decoded.name, app.name);
      expect(decoded.executablePath, app.executablePath);
      expect(decoded.arguments, app.arguments);
      expect(decoded.workingDirectory, app.workingDirectory);
      expect(decoded.enabled, isTrue);
    });
  });

  group('AppListItem', () {
    test('omits sensitive fields', () {
      const item = AppListItem(id: 'x', name: 'Chrome', enabled: true);
      final json = item.toJson();
      expect(json.containsKey('executablePath'), isFalse);
      expect(json.containsKey('arguments'), isFalse);
      expect(json['name'], 'Chrome');
    });
  });

  group('PairingPayload', () {
    test('encode/decode is stable', () {
      const payload = PairingPayload(
        agentName: 'My PC',
        host: '192.168.0.10',
        port: 8765,
        pairingCode: 'AB12CD',
      );
      final decoded = PairingPayload.tryDecode(payload.encode());
      expect(decoded, isNotNull);
      expect(decoded!.host, '192.168.0.10');
      expect(decoded.port, 8765);
      expect(decoded.pairingCode, 'AB12CD');
    });

    test('rejects garbage', () {
      expect(PairingPayload.tryDecode('not-json'), isNull);
    });
  });

  group('PairStatus', () {
    test('parses names', () {
      expect(PairStatus.fromName('approved'), PairStatus.approved);
      expect(PairStatus.fromName('weird'), PairStatus.pending);
    });
  });
}
