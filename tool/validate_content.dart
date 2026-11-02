import 'dart:io';

import 'package:xoai_castle/core/content/content_dir.dart';
import 'package:xoai_castle/core/content/content_validator.dart';

void main(List<String> args) {
  final snapshot = readContentDir(args.isEmpty ? 'content' : args.first);
  final errors = validateContent(snapshot.json, assetPaths: snapshot.assets);
  if (errors.isEmpty) {
    stdout.writeln('Nội dung hợp lệ ✅');
    return;
  }
  for (final error in errors) {
    stderr.writeln('❌ $error');
  }
  exit(1);
}
