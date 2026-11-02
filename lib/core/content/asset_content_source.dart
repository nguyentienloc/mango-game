import 'package:flutter/services.dart';

import 'content_repository.dart';

class AssetContentSource implements ContentSource {
  @override
  Future<String> readText(String path) => rootBundle.loadString('content/$path');
}
