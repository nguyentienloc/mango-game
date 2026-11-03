import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/features/games/trace/trace_pad.dart';

double _length(List<TracePoint> pts) {
  var t = 0.0;
  for (var i = 1; i < pts.length; i++) {
    t += pts[i - 1].distanceTo(pts[i]);
  }
  return t;
}

void main() {
  test('short strokes get no direction arrow, long ones do', () {
    expect(shouldDrawArrow(0.1), isFalse);
    expect(shouldDrawArrow(0.2499), isFalse);
    expect(shouldDrawArrow(0.25), isTrue);
    expect(shouldDrawArrow(0.8), isTrue);
  });

  test('the Ư horn is too short for an arrow; every first stroke of a letter still gets one', () async {
    final content = await ContentRepository(FileContentSource('content')).load();
    final u = content.lettersVi.firstWhere((l) => l.char == 'Ư');
    expect(shouldDrawArrow(_length(u.strokes.last.sample(step: 0.05))), isFalse);
    for (final l in content.lettersVi) {
      expect(shouldDrawArrow(_length(l.strokes.first.sample(step: 0.05))), isTrue, reason: l.char);
    }
  });
}
