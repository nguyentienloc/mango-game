import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/updater/app_updater.dart';

class FakeReleaseApi implements ReleaseApi {
  FakeReleaseApi(this.result);
  final Object result;

  @override
  Future<Map<String, dynamic>> latestRelease() async {
    if (result is Exception) throw result;
    return result as Map<String, dynamic>;
  }
}

Map<String, dynamic> release(String tag, {bool withApk = true}) => {
      'tag_name': tag,
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt', 'size': 10},
        if (withApk) {'name': 'xoai-$tag.apk', 'browser_download_url': 'https://x/xoai.apk', 'size': 20971520},
      ],
    };

AppUpdater updater(Object result) =>
    AppUpdater(api: FakeReleaseApi(result), dio: Dio(), currentVersion: '0.1.0');

void main() {
  test('newer release with an APK is available', () async {
    final check = await updater(release('v0.2.0')).check();
    expect(check, isA<UpdateAvailable>());
    final info = (check as UpdateAvailable).release;
    expect(info.version, '0.2.0');
    expect(info.apkUrl, 'https://x/xoai.apk');
    expect(info.sizeBytes, 20971520);
  });

  test('same version is up to date', () async {
    expect(await updater(release('v0.1.0')).check(), isA<UpToDate>());
  });

  test('newer release without an APK fails with a message', () async {
    final check = await updater(release('v0.2.0', withApk: false)).check();
    expect(check, isA<CheckFailed>());
    expect((check as CheckFailed).message, contains('0.2.0'));
  });

  test('API errors become CheckFailed', () async {
    expect(await updater(Exception('offline')).check(), isA<CheckFailed>());
  });
}
