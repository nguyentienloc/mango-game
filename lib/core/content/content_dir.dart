import 'dart:io';

class ContentDirSnapshot {
  ContentDirSnapshot(this.json, this.assets);

  /// JSON files keyed by path relative to the content root.
  final Map<String, String> json;

  /// Every non-JSON file path relative to the content root.
  final Set<String> assets;
}

ContentDirSnapshot readContentDir(String root) {
  final dir = Directory(root);
  final json = <String, String>{};
  final assets = <String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path.substring(dir.path.length + 1).replaceAll(r'\', '/');
    if (rel.endsWith('.json')) {
      json[rel] = entity.readAsStringSync();
    } else {
      assets.add(rel);
    }
  }
  return ContentDirSnapshot(json, assets);
}
