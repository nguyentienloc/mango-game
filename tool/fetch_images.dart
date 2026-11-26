import 'dart:io';

/// Downloads Fluent Emoji 3D images (MIT) for the vocabulary into
/// content/images/vocab/<id>.png. Skips files that already exist.
/// Usage: dart run tool/fetch_images.dart
const _commit = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const _base = 'https://raw.githubusercontent.com/microsoft/fluentui-emoji/$_commit';

/// vocabulary id → Fluent asset folder name.
const _folders = {
  // vocab_christmas
  'christmas_tree': 'Christmas tree', 'santa': 'Santa claus', 'gift': 'Wrapped gift',
  'snowman': 'Snowman without snow', 'reindeer': 'Deer', 'bell': 'Bell', 'star': 'Star', 'candle': 'Candle',
  'cookie': 'Cookie', 'socks': 'Socks', 'sled': 'Sled', 'snowflake': 'Snowflake',
  // vocab_toys
  'teddy_bear': 'Teddy bear', 'ball': 'Soccer ball', 'kite': 'Kite', 'yo_yo': 'Yo-yo', 'robot': 'Robot',
  'balloon': 'Balloon', 'puzzle': 'Puzzle piece', 'drum': 'Drum', 'guitar': 'Guitar', 'skateboard': 'Skateboard',
  'crayon': 'Crayon', 'trumpet': 'Trumpet',
  // vocab_food
  'bread': 'Bread', 'cake': 'Shortcake', 'pizza': 'Pizza', 'egg': 'Egg', 'milk': 'Glass of milk',
  'rice': 'Cooked rice', 'noodles': 'Steaming bowl', 'ice_cream': 'Soft ice cream', 'cheese': 'Cheese wedge',
  'honey': 'Honey pot', 'candy': 'Candy', 'sandwich': 'Sandwich',
  // vocab_body
  'eye': 'Eye', 'ear': 'Ear', 'nose': 'Nose', 'mouth': 'Mouth', 'tooth': 'Tooth', 'tongue': 'Tongue',
  'hand': 'Raised hand', 'foot': 'Foot', 'leg': 'Leg', 'arm': 'Flexed biceps', 'finger': 'Backhand index pointing up',
  // vocab_clothes
  'tshirt': 'T-shirt', 'dress': 'Dress', 'cap': 'Billed cap', 'shoe': 'Running shoe', 'glasses': 'Glasses',
  'coat': 'Coat', 'scarf': 'Scarf', 'gloves': 'Gloves', 'jeans': 'Jeans', 'boot': 'Womans boot', 'crown': 'Crown',
  'backpack': 'Backpack',
  // vocab_nature
  'sun': 'Sun', 'moon': 'Crescent moon', 'cloud': 'Cloud', 'rain': 'Cloud with rain', 'rainbow': 'Rainbow',
  'flower': 'Hibiscus', 'tree': 'Deciduous tree', 'leaf': 'Leaf fluttering in wind', 'mountain': 'Mountain',
  'wave': 'Water wave', 'fire': 'Fire', 'rock': 'Rock',
};

/// Folders of emojis with skin tones: their pictures live in a `Default/` subfolder.
const _skinTones = {'Santa claus', 'Ear', 'Nose', 'Raised hand', 'Foot', 'Leg', 'Flexed biceps', 'Backhand index pointing up'};

/// Path of [folder]'s 3D picture inside the repo's assets/.
String _fluentPath(String folder) {
  final name = folder.toLowerCase().replaceAll(' ', '_');
  return _skinTones.contains(folder) ? '$folder/Default/3D/${name}_3d_default.png' : '$folder/3D/${name}_3d.png';
}

Future<void> main() async {
  final dir = Directory('content/images/vocab')..createSync(recursive: true);
  final client = HttpClient();
  try {
    await _download(client, '$_base/LICENSE', File('${dir.path}/LICENSE-fluentui-emoji.txt'));
    for (final MapEntry(key: id, value: folder) in _folders.entries) {
      final file = File('${dir.path}/$id.png');
      if (file.existsSync()) continue;
      final url = '$_base/assets/${_fluentPath(folder).split('/').map(Uri.encodeComponent).join('/')}';
      if (await _download(client, url, file)) stdout.writeln('✓ $id ← $folder');
    }
  } finally {
    client.close();
  }
}

Future<bool> _download(HttpClient client, String url, File to) async {
  final res = await (await client.getUrl(Uri.parse(url))).close();
  if (res.statusCode != 200) {
    stderr.writeln('❌ $url → HTTP ${res.statusCode}');
    exitCode = 1;
    await res.drain<void>();
    return false;
  }
  await res.pipe(to.openWrite());
  return true;
}
