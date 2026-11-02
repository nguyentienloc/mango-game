import 'dart:io';

import 'content_repository.dart';

class FileContentSource implements ContentSource {
  FileContentSource(this.root);

  final String root;

  @override
  Future<String> readText(String path) => File('$root/$path').readAsString();
}
