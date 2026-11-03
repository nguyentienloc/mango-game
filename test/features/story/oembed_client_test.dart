import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/oembed_client.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions) _respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

(OEmbedClient, _FakeAdapter) _client(ResponseBody Function(RequestOptions) respond) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  return (OEmbedClient(dio), adapter);
}

void main() {
  test('200 gives the title and asks the YouTube oEmbed endpoint for that video', () async {
    final (client, adapter) = _client((_) => _json(200, {'title': 'Tấm Cám', 'author_name': 'Kênh'}));
    final result = await client.fetch('abcdefghijk');
    expect(result, isA<OEmbedOk>());
    expect((result as OEmbedOk).title, 'Tấm Cám');
    final req = adapter.requests.single;
    expect(req.uri.origin + req.uri.path, 'https://www.youtube.com/oembed');
    expect(req.uri.queryParameters['url'], 'https://www.youtube.com/watch?v=abcdefghijk');
    expect(req.uri.queryParameters['format'], 'json');
    expect(req.connectTimeout, const Duration(seconds: 8));
    expect(req.receiveTimeout, const Duration(seconds: 8));
  });

  test('401 and 403 mean the video cannot be embedded', () async {
    for (final code in [401, 403]) {
      final (client, _) = _client((_) => _json(code, {}));
      expect(await client.fetch('abcdefghijk'), isA<OEmbedNotEmbeddable>(), reason: '$code');
    }
  });

  test('404 and 400 mean the video was not found', () async {
    for (final code in [404, 400]) {
      final (client, _) = _client((_) => _json(code, {}));
      expect(await client.fetch('abcdefghijk'), isA<OEmbedNotFound>(), reason: '$code');
    }
  });

  test('other statuses, network errors and bad bodies are a plain failure', () async {
    final (c500, _) = _client((_) => _json(500, {}));
    expect(await c500.fetch('abcdefghijk'), isA<OEmbedFailed>());

    final (cNet, _) = _client((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    expect(await cNet.fetch('abcdefghijk'), isA<OEmbedFailed>());

    final (cTimeout, _) = _client(
      (o) => throw DioException.connectionTimeout(timeout: const Duration(seconds: 8), requestOptions: o),
    );
    expect(await cTimeout.fetch('abcdefghijk'), isA<OEmbedFailed>());

    final (cNoTitle, _) = _client((_) => _json(200, {'author_name': 'x'}));
    expect(await cNoTitle.fetch('abcdefghijk'), isA<OEmbedFailed>());

    final (cHtml, _) = _client((_) => ResponseBody.fromString('<html>', 200));
    expect(await cHtml.fetch('abcdefghijk'), isA<OEmbedFailed>());
  });
}
