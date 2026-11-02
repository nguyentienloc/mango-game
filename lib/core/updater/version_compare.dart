String normalizeVersion(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  return s.split(RegExp(r'[+-]')).first;
}

List<int>? _parts(String v) {
  final parts = normalizeVersion(v).split('.');
  if (parts.length > 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.contains(null)) return null;
  return [...nums.cast<int>(), ...List.filled(3 - nums.length, 0)];
}

/// True when [candidate] is a strictly higher major.minor.patch than [current].
bool isNewerVersion(String candidate, String current) {
  final a = _parts(candidate);
  final b = _parts(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
