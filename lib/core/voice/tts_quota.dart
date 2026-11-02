/// Longest per-minute rate-limit wait the voice generator will sit through.
const maxQuotaWaitSeconds = 600;

/// True when a 429 body says the daily quota (not the per-minute one) is spent.
/// Per-minute bodies look like "... (limit: 3 requests per minute on Free Tier).
/// Please retry in 43s ...", so only an explicit daily marker counts.
bool isDailyQuota(String body) {
  final b = body.toLowerCase();
  return b.contains('per day') || b.contains('perday') || b.contains('daily');
}

/// Parses "Please retry in 43s" / "retry in 4m55s" / "retry in 1h2m3s" (any case)
/// into seconds, plus a 3 s margin. Null when there is no parsable delay.
int? retryDelaySeconds(String body) {
  final m = RegExp(r'retry in (?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?', caseSensitive: false).firstMatch(body);
  if (m == null || (m[1] == null && m[2] == null && m[3] == null)) return null;
  final secs = int.parse(m[1] ?? '0') * 3600 + int.parse(m[2] ?? '0') * 60 + double.parse(m[3] ?? '0').ceil();
  return secs + 3;
}

/// How long to wait before retrying a 429, or null when the quota should be
/// treated as exhausted for the day (daily marker, no delay given, or the delay
/// is longer than [maxQuotaWaitSeconds]).
int? quotaWaitSeconds(String body) {
  if (isDailyQuota(body)) return null;
  final wait = retryDelaySeconds(body);
  if (wait == null || wait > maxQuotaWaitSeconds) return null;
  return wait;
}
