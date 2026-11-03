final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
const _hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'www.youtube-nocookie.com', 'youtube-nocookie.com'};
const _idPaths = {'shorts', 'embed', 'live'};

/// Pulls the 11-character video id out of a YouTube link a parent pasted:
/// watch, youtu.be, shorts, embed and live links, or a bare id. Null when the
/// text is not a link to a single video.
String? parseYoutubeId(String input) {
  final text = input.trim();
  if (_idPattern.hasMatch(text)) return text;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || !uri.hasAuthority) return null;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? candidate;
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (segments.length == 1) candidate = segments[0];
  } else if (_hosts.contains(host)) {
    if (segments.length == 1 && segments[0] == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length == 2 && _idPaths.contains(segments[0])) {
      candidate = segments[1];
    }
  }
  return candidate != null && _idPattern.hasMatch(candidate) ? candidate : null;
}
