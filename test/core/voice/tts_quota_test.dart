import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/voice/tts_quota.dart';

void main() {
  const perMinute = '{"error":{"message":"Rate limit exceeded for model gemini-3.8-flash-tts '
      '(limit: 3 requests per minute on Free Tier). Please retry in 43s or upgrade your tier."}}';
  const perDay = '{"error":{"message":"Rate limit exceeded for model gemini-3.8-flash-tts '
      '(limit: 10 requests per day on Free Tier). Please retry in 4m55s or upgrade your tier."}}';

  test('per-minute limit waits retry delay plus margin', () {
    expect(isDailyQuota(perMinute), isFalse);
    expect(quotaWaitSeconds(perMinute), 46);
  });

  test('per-day limit is treated as exhausted', () {
    expect(isDailyQuota(perDay), isTrue);
    expect(retryDelaySeconds(perDay), 298);
    expect(quotaWaitSeconds(perDay), isNull);
  });

  test('retry text is matched case-insensitively and with h/m/s parts', () {
    expect(retryDelaySeconds('Retry in 43s'), 46);
    expect(retryDelaySeconds('please retry in 1h2m3s'), 3723 + 3);
    expect(retryDelaySeconds('retry in 2.5s'), 6);
    expect(retryDelaySeconds('no delay here'), isNull);
  });

  test('waits longer than 10 minutes or without a delay count as exhausted', () {
    expect(quotaWaitSeconds('limit per minute. retry in 11m'), isNull);
    expect(quotaWaitSeconds('limit per minute. retry in 9m'), 543);
    expect(quotaWaitSeconds('limit per minute'), isNull);
  });
}
