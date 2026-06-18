import 'dart:io';

/// Helpers for discovering the local hostname and usable LAN IPv4 addresses.
class NetworkInfo {
  const NetworkInfo._();

  static String hostName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'PC';
    }
  }

  static String platformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Returns non-loopback IPv4 addresses, best LAN candidate first.
  static Future<List<String>> localIpv4Addresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final ni in interfaces) {
        for (final addr in ni.addresses) {
          if (!addr.isLoopback) {
            result.add(addr.address);
          }
        }
      }
    } catch (_) {
      // Ignore — return whatever we have.
    }
    // Prefer common private LAN ranges (192.168.x / 10.x) at the top.
    result.sort((a, b) {
      int rank(String ip) {
        if (ip.startsWith('192.168.')) return 0;
        if (ip.startsWith('10.')) return 1;
        if (ip.startsWith('172.')) return 2;
        return 3;
      }

      return rank(a).compareTo(rank(b));
    });
    return result;
  }
}
