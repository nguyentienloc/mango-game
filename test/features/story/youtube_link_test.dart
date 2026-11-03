import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/features/story/youtube_link.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  group('valid links', () {
    final cases = <String, String>{
      'watch': 'https://www.youtube.com/watch?v=$id',
      'no scheme': 'youtube.com/watch?v=$id',
      'http': 'http://youtube.com/watch?v=$id',
      'mobile host': 'https://m.youtube.com/watch?v=$id',
      'music host': 'https://music.youtube.com/watch?v=$id',
      'extra params after': 'https://www.youtube.com/watch?v=$id&t=42s&list=PL123',
      'extra params before': 'https://www.youtube.com/watch?feature=share&v=$id',
      'youtu.be': 'https://youtu.be/$id',
      'youtu.be with params': 'https://youtu.be/$id?si=abcdef&t=10',
      'shorts': 'https://www.youtube.com/shorts/$id',
      'embed': 'https://www.youtube.com/embed/$id',
      'live': 'https://www.youtube.com/live/$id',
      'nocookie embed': 'https://www.youtube-nocookie.com/embed/$id',
      'bare id': id,
      'padded': '   https://youtu.be/$id \n',
      'padded bare id': '  $id  ',
      'trailing slash': 'https://youtu.be/$id/',
      'dash and underscore': 'https://youtu.be/a-b_c-d_e-f',
    };
    for (final e in cases.entries) {
      test(e.key, () {
        final expected = e.key == 'dash and underscore' ? 'a-b_c-d_e-f' : id;
        expect(parseYoutubeId(e.value), expected);
      });
    }
  });

  group('invalid links', () {
    final cases = <String, String>{
      'other domain': 'https://vimeo.com/watch?v=$id',
      'look-alike domain': 'https://notyoutube.com/watch?v=$id',
      'domain suffix trick': 'https://youtube.com.evil.com/watch?v=$id',
      'id too short': 'https://youtu.be/dQw4w9WgXc',
      'id too long': 'https://youtu.be/dQw4w9WgXcQQ',
      'bare id too short': 'dQw4w9WgXc',
      'empty': '',
      'blank': '   ',
      'channel': 'https://www.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw',
      'playlist only': 'https://www.youtube.com/playlist?list=PLabcdefghijk',
      'home page': 'https://www.youtube.com/',
      'bad characters': 'https://youtu.be/dQw4w9Wg!cQ',
      'plain text': 'truyen co tich',
    };
    for (final e in cases.entries) {
      test(e.key, () => expect(parseYoutubeId(e.value), isNull));
    }
  });
}
