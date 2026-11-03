import 'dart:async';
import 'dart:io';

abstract interface class ConnectivityProbe {
  /// Whether the internet (YouTube) looks reachable right now.
  Future<bool> online();
}

/// Resolves www.youtube.com; no answer within [timeout] counts as offline.
class DnsConnectivityProbe implements ConnectivityProbe {
  const DnsConnectivityProbe({this.host = 'www.youtube.com', this.timeout = const Duration(seconds: 3)});

  final String host;
  final Duration timeout;

  @override
  Future<bool> online() async {
    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on Object {
      return false;
    }
  }
}
