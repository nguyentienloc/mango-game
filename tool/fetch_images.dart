import 'dart:io';

/// Downloads Fluent Emoji 3D images (MIT) for the vocabulary into
/// content/images/vocab/<id>.png. Skips files that already exist.
/// Usage: dart run tool/fetch_images.dart
const _commit = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const _base = 'https://raw.githubusercontent.com/microsoft/fluentui-emoji/$_commit';

/// vocabulary id → Fluent asset folder name.
const _folders = {
  'cat': 'Cat face', 'dog': 'Dog face', 'lion': 'Lion', 'elephant': 'Elephant', 'tiger': 'Tiger face',
  'monkey': 'Monkey face', 'rabbit': 'Rabbit face', 'bear': 'Bear', 'fish': 'Fish', 'bird': 'Bird',
  'duck': 'Duck', 'cow': 'Cow face', 'pig': 'Pig face', 'horse': 'Horse face', 'chicken': 'Baby chick',
  'frog': 'Frog', 'giraffe': 'Giraffe', 'zebra': 'Zebra', 'panda': 'Panda', 'penguin': 'Penguin',
  'apple': 'Red apple', 'banana': 'Banana', 'orange': 'Tangerine', 'grapes': 'Grapes', 'watermelon': 'Watermelon',
  'strawberry': 'Strawberry', 'mango': 'Mango', 'pineapple': 'Pineapple', 'pear': 'Pear', 'cherry': 'Cherries',
  'lemon': 'Lemon', 'peach': 'Peach', 'coconut': 'Coconut',
  'carrot': 'Carrot', 'tomato': 'Tomato', 'corn': 'Ear of corn', 'potato': 'Potato', 'broccoli': 'Broccoli',
  'cucumber': 'Cucumber',
  'car': 'Automobile', 'bus': 'Bus', 'train': 'Train', 'airplane': 'Airplane', 'boat': 'Sailboat', 'bicycle': 'Bicycle',
};

Future<void> main() async {
  final dir = Directory('content/images/vocab')..createSync(recursive: true);
  final client = HttpClient();
  try {
    await _download(client, '$_base/LICENSE', File('${dir.path}/LICENSE-fluentui-emoji.txt'));
    for (final MapEntry(key: id, value: folder) in _folders.entries) {
      final file = File('${dir.path}/$id.png');
      if (file.existsSync()) continue;
      final name = '${folder.toLowerCase().replaceAll(' ', '_')}_3d.png';
      await _download(client, '$_base/assets/${Uri.encodeComponent(folder)}/3D/$name', file);
      stdout.writeln('✓ $id ← $folder');
    }
  } finally {
    client.close();
  }
}

Future<void> _download(HttpClient client, String url, File to) async {
  final res = await (await client.getUrl(Uri.parse(url))).close();
  if (res.statusCode != 200) {
    stderr.writeln('❌ $url → HTTP ${res.statusCode}');
    exitCode = 1;
    await res.drain<void>();
    return;
  }
  await res.pipe(to.openWrite());
}
