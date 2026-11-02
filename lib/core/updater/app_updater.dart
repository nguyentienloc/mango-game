import 'package:dio/dio.dart';

import 'version_compare.dart';

class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.apkUrl, required this.sizeBytes});

  final String version;
  final String apkUrl;
  final int sizeBytes;
}

sealed class UpdateCheck {
  const UpdateCheck();
}

class UpToDate extends UpdateCheck {
  const UpToDate();
}

class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.release);

  final ReleaseInfo release;
}

class CheckFailed extends UpdateCheck {
  const CheckFailed(this.message);

  final String message;
}

abstract interface class ReleaseApi {
  Future<Map<String, dynamic>> latestRelease();
}

class GithubReleaseApi implements ReleaseApi {
  GithubReleaseApi(this._dio, this.repo);

  final Dio _dio;
  final String repo;

  @override
  Future<Map<String, dynamic>> latestRelease() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$repo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    return res.data!;
  }
}

class AppUpdater {
  AppUpdater({required ReleaseApi api, required Dio dio, required this.currentVersion})
      : _api = api,
        _dio = dio;

  final ReleaseApi _api;
  final Dio _dio;
  final String currentVersion;

  Future<UpdateCheck> check() async {
    try {
      final json = await _api.latestRelease();
      final version = normalizeVersion(json['tag_name'] as String);
      if (!isNewerVersion(version, currentVersion)) return const UpToDate();
      final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
      final apk = assets.where((a) => (a['name'] as String).endsWith('.apk')).firstOrNull;
      if (apk == null) return CheckFailed('Bản $version không có file APK');
      return UpdateAvailable(ReleaseInfo(
        version: version,
        apkUrl: apk['browser_download_url'] as String,
        sizeBytes: apk['size'] as int,
      ));
    } catch (e) {
      return CheckFailed('Không kiểm tra được cập nhật (mất mạng hoặc chưa có bản phát hành): $e');
    }
  }

  /// Downloads the APK into [dir] and returns its path.
  Future<String> download(
    ReleaseInfo r,
    String dir, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = '$dir/xoai-${r.version}.apk';
    await _dio.download(r.apkUrl, path, onReceiveProgress: onProgress, cancelToken: cancelToken);
    return path;
  }
}
