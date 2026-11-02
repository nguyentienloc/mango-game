import 'dart:convert';

import 'content_validator.dart';
import 'models.dart';

abstract interface class ContentSource {
  /// Reads a file by its path relative to content/.
  Future<String> readText(String path);
}

class ContentException implements Exception {
  ContentException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'ContentException: ${errors.join('; ')}';
}

class ContentRepository {
  ContentRepository(this.source);

  final ContentSource source;

  Future<ContentBundle> load() async {
    final manifestText = await source.readText('manifest.json');
    final files = <String, String>{'manifest.json': manifestText};
    final List<String> paths;
    try {
      paths = manifestPaths(jsonDecode(manifestText) as Map<String, dynamic>);
    } on Object {
      throw ContentException(validateContent(files));
    }
    for (final path in paths) {
      files[path] = await source.readText(path);
    }
    final errors = validateContent(files);
    if (errors.isNotEmpty) throw ContentException(errors);
    return ContentBundle.fromFiles(files);
  }
}
