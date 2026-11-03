import 'package:dio/dio.dart';

sealed class OEmbedResult {
  const OEmbedResult();
}

class OEmbedOk extends OEmbedResult {
  const OEmbedOk(this.title);

  final String title;
}

/// The owner disabled embedding (HTTP 401 / 403).
class OEmbedNotEmbeddable extends OEmbedResult {
  const OEmbedNotEmbeddable();
}

/// No such video, or it is private (HTTP 404 / 400).
class OEmbedNotFound extends OEmbedResult {
  const OEmbedNotFound();
}

/// No network, timeout or an answer we cannot read.
class OEmbedFailed extends OEmbedResult {
  const OEmbedFailed();
}

const _timeout = Duration(seconds: 8);

/// Asks YouTube whether a video exists and may be embedded, and for its title.
class OEmbedClient {
  OEmbedClient(this._dio);

  final Dio _dio;

  Future<OEmbedResult> fetch(String videoId) async {
    try {
      final response = await _dio.fetch<Object?>(
        RequestOptions(
          path: 'https://www.youtube.com/oembed',
          queryParameters: {'url': 'https://www.youtube.com/watch?v=$videoId', 'format': 'json'},
          connectTimeout: _timeout,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (_) => true,
        ),
      );
      return switch (response.statusCode) {
        200 => _fromBody(response.data),
        401 || 403 => const OEmbedNotEmbeddable(),
        404 || 400 => const OEmbedNotFound(),
        _ => const OEmbedFailed(),
      };
    } on DioException {
      return const OEmbedFailed();
    }
  }

  OEmbedResult _fromBody(Object? data) {
    final title = data is Map ? data['title'] : null;
    return title is String && title.isNotEmpty ? OEmbedOk(title) : const OEmbedFailed();
  }
}
