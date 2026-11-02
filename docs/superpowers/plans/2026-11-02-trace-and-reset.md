# Tô chữ in hoa + Đặt lại dữ liệu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v0.3.0 — trò ✏️ tô chữ in hoa A–Z (từng nét, chấm dễ, chặn tô nguệch ngoạc) và nút "Đặt lại dữ liệu game" trong khu bố mẹ.

**Architecture:** Nét chữ khai báo trong `letters_en.json` (đoạn `line`/`arc`, tọa độ 0–1). Logic thuần Dart: lấy mẫu nét → điểm, chấm nét (độ phủ + độ chính xác), phiên tô một chữ, dựng lượt. UI: `TracePad` (CustomPainter + pan gesture) và `TraceScreen` theo khuôn `VocabScreen`. Reset: `ProgressResetter` (drift transaction) + hộp xác nhận ở `ParentScreen`.

**Tech Stack:** Flutter 3.47.9, Dart 3, flutter_riverpod 3.4.3, drift (không đổi schema), Vbee qua `tool/gen_voice.dart`.

**Spec:** `docs/superpowers/specs/2026-11-02-trace-and-reset-design.md`

## Global Constraints

- Nhánh `feat/trace-and-reset`. Phát hành `0.3.0+3`, tag `v0.3.0`.
- Tô chữ: 3 chữ/lượt; khóa `trace_en_upper:<CHAR>`; `maxNew: 3`; phiên `game: 'trace'`.
- Chấm nét: tolerance 0,12 (theo cạnh khung = 1); đạt khi coverage ≥ 0,8 **và** precision ≥ 0,7; bước lấy mẫu 0,02.
- Kết quả chữ: có nét nào sai ≥ 3 lần → `retry`, ngược lại `firstTry`. +1 ❄️/chữ firstTry, +5 ❄️/lượt.
- Cung: `[cx, cy, rx, ry, startDeg, sweepDeg]`, 0° = phải, góc dương = chiều kim đồng hồ trên màn hình (y xuống): `x = cx + rx·cos θ`, `y = cy + ry·sin θ`.
- Câu nói: `trace_prompt` = en "Let's write {letter}!"; dùng lại `letter_example`, nhóm `try_again`, `go_home`, `error_home`.
- Reset xóa `item_stats`, `sessions`, đặt `rewards` về mặc định (id 1); **giữ** `profile`.
- Mọi chạm điều hướng có tiếng; vừa màn 360×640 dp; chữ cho bố mẹ bằng tiếng Việt.
- `flutter analyze --no-fatal-infos` sạch lỗi/cảnh báo, `flutter test` xanh trước mỗi commit.

---

### Task 1: Dữ liệu nét chữ A–Z + lấy mẫu + validator

**Files:**
- Create: `lib/core/content/strokes.dart`
- Modify: `lib/core/content/models.dart` (`LetterItem.strokes`), `lib/core/content/content_validator.dart` (`_checkLetters`), `content/packs/letters_en.json`, `content/manifest.json`, `test/support/content_fixture.dart`
- Test: `test/core/content/strokes_test.dart`, `test/core/content/content_validator_test.dart` (thêm case)

**Interfaces:**
- Produces:
  - `class TracePoint { const TracePoint(double x, double y); double distanceTo(TracePoint o); }`
  - `sealed class StrokeSegment`; `LineSegment(List<TracePoint> points)`; `ArcSegment(cx, cy, rx, ry, startDeg, sweepDeg)`; mỗi loại có `List<TracePoint> sample(double step)`.
  - `class Stroke { const Stroke(List<StrokeSegment> segments); factory Stroke.fromJson(List json); List<TracePoint> sample({double step = 0.02}); }` — điểm đầu là điểm bắt đầu của nét; các đoạn nối tiếp, bỏ điểm trùng ở chỗ nối.
  - `LetterItem.strokes: List<Stroke>` (rỗng nếu JSON không có).
  - Validator lỗi (tiếng Việt) cho nét sai.

- [ ] **Step 1: Test (failing)** — `test/core/content/strokes_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/strokes.dart';

void main() {
  test('a line is sampled at roughly the step size, ends included', () {
    final pts = const Stroke([LineSegment([TracePoint(0, 0), TracePoint(1, 0)])]).sample(step: 0.1);
    expect(pts.first.x, 0);
    expect(pts.last.x, closeTo(1, 1e-9));
    expect(pts.length, inInclusiveRange(10, 12));
  });

  test('a clockwise quarter arc from the top goes to the right', () {
    final pts = const Stroke([ArcSegment(0.5, 0.5, 0.4, 0.4, -90, 90)]).sample();
    expect(pts.first.x, closeTo(0.5, 1e-9));
    expect(pts.first.y, closeTo(0.1, 1e-9));
    expect(pts.last.x, closeTo(0.9, 1e-9));
    expect(pts.last.y, closeTo(0.5, 1e-9));
  });

  test('segments join without duplicating the joint', () {
    final s = const Stroke([
      LineSegment([TracePoint(0.2, 0.1), TracePoint(0.2, 0.6)]),
      ArcSegment(0.5, 0.6, 0.3, 0.3, 180, -180),
    ]);
    final pts = s.sample(step: 0.05);
    for (var i = 1; i < pts.length; i++) {
      expect(pts[i].distanceTo(pts[i - 1]), greaterThan(0));
      expect(pts[i].distanceTo(pts[i - 1]), lessThan(0.08));
    }
    expect(pts.last.x, closeTo(0.8, 1e-9));
  });

  test('fromJson reads line and arc segments', () {
    final s = Stroke.fromJson([
      {'line': [[0.1, 0.1], [0.1, 0.9]]},
      {'arc': [0.5, 0.5, 0.2, 0.2, 0, 90]},
    ]);
    expect(s.segments, hasLength(2));
    expect(s.segments.first, isA<LineSegment>());
    expect(s.segments.last, isA<ArcSegment>());
  });

  test('every shipped letter has strokes that stay inside the box', () async {
    final bundle = await ContentRepository(FileContentSource('content')).load();
    expect(bundle.lettersEn, hasLength(26));
    for (final l in bundle.lettersEn) {
      expect(l.strokes, isNotEmpty, reason: l.char);
      for (final s in l.strokes) {
        for (final p in s.sample()) {
          expect(p.x, inInclusiveRange(-0.01, 1.01), reason: l.char);
          expect(p.y, inInclusiveRange(-0.01, 1.01), reason: l.char);
        }
      }
    }
  });
}
```
Thêm vào `content_validator_test.dart`:
```dart
  test('letters need valid strokes', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    (letters['items'] as List)[0] = {
      'char': 'A',
      'example': {'word': 'Apple', 'emoji': '🍎'},
      'strokes': [
        [ {'line': [[0.5, 0.1]]} ],
        [ {'arc': [0.5, 0.5, 0, 0.2, 0, 90]} ],
        [ {'line': [[0.5, 1.5], [0.2, 0.2]]} ],
      ],
    };
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, containsAll([
      'packs/letters_en.json items[0] strokes[0][0]: "line" cần ít nhất 2 điểm',
      'packs/letters_en.json items[0] strokes[1][0]: "arc" cần rx, ry > 0 và sweep khác 0',
      'packs/letters_en.json items[0] strokes[2][0]: tọa độ phải trong khoảng 0–1',
    ]));
  });

  test('letters without strokes are reported', () {
    final letters = readJson(validFiles(), 'packs/letters_en.json');
    ((letters['items'] as List)[0] as Map).remove('strokes');
    final errors = validateContent(withJson(validFiles(), 'packs/letters_en.json', letters));
    expect(errors, contains('packs/letters_en.json items[0]: thiếu "strokes"'));
  });
```
Trong `test/support/content_fixture.dart`, thêm `'strokes'` cho A và B trong fixture:
```dart
{'char': 'A', 'example': {'word': 'Apple', 'emoji': '🍎'}, 'strokes': [[{'line': [[0.5, 0.1], [0.15, 0.9]]}]]},
{'char': 'B', 'example': {'word': 'Ball', 'emoji': '⚽'}, 'strokes': [[{'line': [[0.25, 0.1], [0.25, 0.9]]}]]},
```

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `lib/core/content/strokes.dart`**
```dart
import 'dart:math';

class TracePoint {
  const TracePoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(TracePoint o) => sqrt(pow(x - o.x, 2) + pow(y - o.y, 2));
}

sealed class StrokeSegment {
  const StrokeSegment();

  /// Points along the segment, about [step] apart, both ends included.
  List<TracePoint> sample(double step);

  static StrokeSegment fromJson(Map<String, dynamic> json) {
    final line = json['line'];
    if (line != null) {
      return LineSegment([
        for (final p in line as List) TracePoint(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
      ]);
    }
    final a = (json['arc'] as List).map((v) => (v as num).toDouble()).toList();
    return ArcSegment(a[0], a[1], a[2], a[3], a[4], a[5]);
  }
}

class LineSegment extends StrokeSegment {
  const LineSegment(this.points);

  final List<TracePoint> points;

  @override
  List<TracePoint> sample(double step) {
    final out = <TracePoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final n = max(1, (a.distanceTo(b) / step).ceil());
      for (var k = 1; k <= n; k++) {
        out.add(TracePoint(a.x + (b.x - a.x) * k / n, a.y + (b.y - a.y) * k / n));
      }
    }
    return out;
  }
}

/// Elliptical arc. Angles in degrees; 0° points right and positive sweep is
/// clockwise on screen (y grows downwards).
class ArcSegment extends StrokeSegment {
  const ArcSegment(this.cx, this.cy, this.rx, this.ry, this.startDeg, this.sweepDeg);

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double startDeg;
  final double sweepDeg;

  @override
  List<TracePoint> sample(double step) {
    final sweep = sweepDeg * pi / 180;
    final n = max(2, (sweep.abs() * max(rx, ry) / step).ceil());
    final start = startDeg * pi / 180;
    return [
      for (var k = 0; k <= n; k++)
        TracePoint(cx + rx * cos(start + sweep * k / n), cy + ry * sin(start + sweep * k / n)),
    ];
  }
}

class Stroke {
  const Stroke(this.segments);

  factory Stroke.fromJson(List<dynamic> json) =>
      Stroke([for (final s in json) StrokeSegment.fromJson(s as Map<String, dynamic>)]);

  final List<StrokeSegment> segments;

  List<TracePoint> sample({double step = 0.02}) {
    final out = <TracePoint>[];
    for (final seg in segments) {
      final pts = seg.sample(step);
      out.addAll(out.isNotEmpty && out.last.distanceTo(pts.first) < 1e-6 ? pts.skip(1) : pts);
    }
    return out;
  }
}
```
`LetterItem`: thêm `final List<Stroke> strokes;` (mặc định `const []`), đọc trong `fromJson`: `strokes: [for (final s in (json['strokes'] as List? ?? const [])) Stroke.fromJson(s as List)]`.

- [ ] **Step 4: Validator** — trong `_checkLetters`, sau phần `example`, thêm (dùng cho từng `item`, `where`):
```dart
    final strokes = item['strokes'];
    if (strokes is! List || strokes.isEmpty) {
      errors.add('$where: thiếu "strokes"');
      continue;
    }
    bool inBox(Object? v) => v is num && v >= 0 && v <= 1;
    for (final (si, stroke) in strokes.indexed) {
      if (stroke is! List || stroke.isEmpty) {
        errors.add('$where strokes[$si]: nét phải là danh sách đoạn không rỗng');
        continue;
      }
      for (final (gi, seg) in stroke.indexed) {
        final sw = '$where strokes[$si][$gi]';
        if (seg is! Map<String, dynamic>) {
          errors.add('$sw: phải là object');
          continue;
        }
        final line = seg['line'];
        final arc = seg['arc'];
        if (line is List) {
          if (line.length < 2) {
            errors.add('$sw: "line" cần ít nhất 2 điểm');
          } else if (!line.every((p) => p is List && p.length == 2 && inBox(p[0]) && inBox(p[1]))) {
            errors.add('$sw: tọa độ phải trong khoảng 0–1');
          }
        } else if (arc is List) {
          if (arc.length != 6 || !arc.every((v) => v is num)) {
            errors.add('$sw: "arc" cần 6 số [cx, cy, rx, ry, start, sweep]');
          } else if ((arc[2] as num) <= 0 || (arc[3] as num) <= 0 || arc[5] == 0) {
            errors.add('$sw: "arc" cần rx, ry > 0 và sweep khác 0');
          } else if (!inBox(arc[0]) || !inBox(arc[1])) {
            errors.add('$sw: tọa độ phải trong khoảng 0–1');
          }
        } else {
          errors.add('$sw: cần "line" hoặc "arc"');
        }
      }
    }
```
(Đặt sao cho `continue` của nhánh thiếu `strokes` không bỏ qua các kiểm tra `example` đã chạy trước đó.)

- [ ] **Step 5: Nét cho 26 chữ** — trong `content/packs/letters_en.json`, `"version": 2` (và `manifest.json` `packs.letters_en: 2`), thêm `strokes` cho từng chữ đúng như sau (mỗi `[...]` ngoài cùng là một nét theo thứ tự viết):
```
A: [[{"line":[[0.5,0.1],[0.15,0.9]]}], [{"line":[[0.5,0.1],[0.85,0.9]]}], [{"line":[[0.3,0.6],[0.7,0.6]]}]]
B: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.55,0.1]]},{"arc":[0.55,0.3,0.2,0.2,-90,180]},{"line":[[0.55,0.5],[0.25,0.5]]}], [{"line":[[0.25,0.5],[0.6,0.5]]},{"arc":[0.6,0.7,0.2,0.2,-90,180]},{"line":[[0.6,0.9],[0.25,0.9]]}]]
C: [[{"arc":[0.5,0.5,0.35,0.4,-40,-280]}]]
D: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.45,0.1]]},{"arc":[0.45,0.5,0.35,0.4,-90,180]},{"line":[[0.45,0.9],[0.25,0.9]]}]]
E: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.75,0.1]]}], [{"line":[[0.25,0.5],[0.65,0.5]]}], [{"line":[[0.25,0.9],[0.75,0.9]]}]]
F: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.75,0.1]]}], [{"line":[[0.25,0.5],[0.65,0.5]]}]]
G: [[{"arc":[0.5,0.5,0.35,0.4,-40,-310]}], [{"line":[[0.85,0.57],[0.55,0.57]]}]]
H: [[{"line":[[0.2,0.1],[0.2,0.9]]}], [{"line":[[0.8,0.1],[0.8,0.9]]}], [{"line":[[0.2,0.5],[0.8,0.5]]}]]
I: [[{"line":[[0.5,0.1],[0.5,0.9]]}], [{"line":[[0.3,0.1],[0.7,0.1]]}], [{"line":[[0.3,0.9],[0.7,0.9]]}]]
J: [[{"line":[[0.65,0.1],[0.65,0.65]]},{"arc":[0.45,0.65,0.2,0.25,0,180]}]]
K: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.75,0.1],[0.25,0.55]]}], [{"line":[[0.38,0.45],[0.78,0.9]]}]]
L: [[{"line":[[0.3,0.1],[0.3,0.9],[0.75,0.9]]}]]
M: [[{"line":[[0.15,0.1],[0.15,0.9]]}], [{"line":[[0.15,0.1],[0.5,0.6],[0.85,0.1]]}], [{"line":[[0.85,0.1],[0.85,0.9]]}]]
N: [[{"line":[[0.2,0.1],[0.2,0.9]]}], [{"line":[[0.2,0.1],[0.8,0.9]]}], [{"line":[[0.8,0.1],[0.8,0.9]]}]]
O: [[{"arc":[0.5,0.5,0.35,0.4,-90,-360]}]]
P: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.55,0.1]]},{"arc":[0.55,0.3,0.2,0.2,-90,180]},{"line":[[0.55,0.5],[0.25,0.5]]}]]
Q: [[{"arc":[0.5,0.5,0.35,0.4,-90,-360]}], [{"line":[[0.55,0.7],[0.85,0.95]]}]]
R: [[{"line":[[0.25,0.1],[0.25,0.9]]}], [{"line":[[0.25,0.1],[0.55,0.1]]},{"arc":[0.55,0.3,0.2,0.2,-90,180]},{"line":[[0.55,0.5],[0.25,0.5]]}], [{"line":[[0.45,0.5],[0.8,0.9]]}]]
S: [[{"arc":[0.5,0.3,0.28,0.2,-20,-250]},{"arc":[0.5,0.7,0.3,0.2,-90,250]}]]
T: [[{"line":[[0.15,0.1],[0.85,0.1]]}], [{"line":[[0.5,0.1],[0.5,0.9]]}]]
U: [[{"line":[[0.2,0.1],[0.2,0.6]]},{"arc":[0.5,0.6,0.3,0.3,180,-180]},{"line":[[0.8,0.6],[0.8,0.1]]}]]
V: [[{"line":[[0.15,0.1],[0.5,0.9],[0.85,0.1]]}]]
W: [[{"line":[[0.1,0.1],[0.3,0.9],[0.5,0.4],[0.7,0.9],[0.9,0.1]]}]]
X: [[{"line":[[0.2,0.1],[0.8,0.9]]}], [{"line":[[0.8,0.1],[0.2,0.9]]}]]
Y: [[{"line":[[0.2,0.1],[0.5,0.5]]}], [{"line":[[0.8,0.1],[0.5,0.5]]}], [{"line":[[0.5,0.5],[0.5,0.9]]}]]
Z: [[{"line":[[0.2,0.1],[0.8,0.1],[0.2,0.9],[0.8,0.9]]}]]
```
(Q: điểm `0.95` vẫn trong [0,1].) Sau khi thêm, vẽ thử một ảnh kiểm tra: viết nhanh một test tạm hoặc script dùng `Stroke.sample()` in ra ASCII 20×20 cho vài chữ cong (B, C, G, J, S, U) để chắc hình đúng — **không commit script tạm**; ghi kết quả nhìn bằng mắt vào report.

- [ ] **Step 6: Chạy toàn bộ test + validate + analyze** → xanh. **Commit** — `feat: stroke data for tracing A–Z`

---

### Task 2: Chấm nét, phiên tô chữ, dựng lượt

**Files:**
- Create: `lib/features/games/trace/trace_logic.dart`
- Test: `test/features/trace/trace_logic_test.dart`

**Interfaces:**
- Consumes: `TracePoint`, `Stroke` (Task 1); `LetterItem`; `ItemStat`, `AnswerOutcome`, `QuestionPicker`.
- Produces:
  - `const kTraceTolerance = 0.12, kMinCoverage = 0.8, kMinPrecision = 0.7;`
  - `class StrokeScore { double coverage; double precision; bool get passed; }`
  - `StrokeScore scoreStroke(List<TracePoint> target, List<TracePoint> drawn, {double tolerance = kTraceTolerance})` — coverage: tỷ lệ điểm `target` cách **đường gấp khúc** `drawn` ≤ tolerance (dùng khoảng cách điểm–đoạn thẳng); precision: tỷ lệ điểm `drawn` cách điểm gần nhất của `target` ≤ tolerance. `drawn` rỗng hoặc 1 điểm → 0/0.
  - `String traceKey(LetterItem l) => 'trace_en_upper:${l.char}'`
  - `class TraceLetterSession { TraceLetterSession(LetterItem letter); LetterItem letter; List<List<TracePoint>> targets; int get strokeIndex; bool get isDone; int failuresOn(int stroke); bool submit(List<TracePoint> drawn); AnswerOutcome get outcome; }` — `submit` chấm nét hiện tại; đạt → sang nét sau, trả true; không đạt → tăng số lần sai của nét đó, trả false. `outcome`: có nét sai ≥ 3 lần → `retry`, ngược lại `firstTry`. Gọi `submit` khi đã xong → `StateError`.
  - `List<LetterItem> buildTraceRound({required List<LetterItem> letters, required Map<String, ItemStat> stats, required QuestionPicker picker, int count = 3, int maxNew = 3})`

- [ ] **Step 1: Test (failing)** — `test/features/trace/trace_logic_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/question_picker.dart';
import 'package:xoai_castle/features/games/trace/trace_logic.dart';

List<TracePoint> line(double x1, double y1, double x2, double y2, [int n = 30]) =>
    [for (var i = 0; i <= n; i++) TracePoint(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n)];

final vertical = const Stroke([LineSegment([TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)])]).sample();

const letterT = LetterItem(char: 'T', exampleWord: 'Tree', exampleEmoji: '🌳', strokes: [
  Stroke([LineSegment([TracePoint(0.15, 0.1), TracePoint(0.85, 0.1)])]),
  Stroke([LineSegment([TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)])]),
]);

void main() {
  group('scoreStroke', () {
    test('tracing right on the stroke passes', () {
      expect(scoreStroke(vertical, line(0.5, 0.1, 0.5, 0.9)).passed, isTrue);
    });

    test('a wobbly trace within tolerance passes', () {
      final wobbly = [for (var i = 0; i <= 40; i++) TracePoint(0.5 + 0.08 * sin(i / 3), 0.1 + 0.8 * i / 40)];
      expect(scoreStroke(vertical, wobbly).passed, isTrue);
    });

    test('tracing only half the stroke fails on coverage', () {
      final s = scoreStroke(vertical, line(0.5, 0.1, 0.5, 0.5));
      expect(s.coverage, lessThan(0.8));
      expect(s.passed, isFalse);
    });

    test('a parallel line too far away fails', () {
      expect(scoreStroke(vertical, line(0.8, 0.1, 0.8, 0.9)).passed, isFalse);
    });

    test('scribbling over the whole box fails on precision', () {
      final scribble = [
        for (var row = 0; row <= 10; row++) ...line(0.05, 0.05 + row * 0.09, 0.95, 0.05 + row * 0.09, 20),
      ];
      final s = scoreStroke(vertical, scribble);
      expect(s.coverage, greaterThanOrEqualTo(0.8));
      expect(s.precision, lessThan(0.7));
      expect(s.passed, isFalse);
    });

    test('fast swipes with few points still count via segment distance', () {
      expect(scoreStroke(vertical, const [TracePoint(0.5, 0.1), TracePoint(0.5, 0.9)]).passed, isTrue);
    });

    test('an empty or single-point drawing fails', () {
      expect(scoreStroke(vertical, const []).passed, isFalse);
      expect(scoreStroke(vertical, const [TracePoint(0.5, 0.5)]).passed, isFalse);
    });
  });

  group('TraceLetterSession', () {
    test('strokes are completed in order and the letter is first-try', () {
      final s = TraceLetterSession(letterT);
      expect(s.targets, hasLength(2));
      expect(s.submit(line(0.15, 0.1, 0.85, 0.1)), isTrue);
      expect(s.strokeIndex, 1);
      expect(s.submit(line(0.5, 0.1, 0.5, 0.9)), isTrue);
      expect(s.isDone, isTrue);
      expect(s.outcome, AnswerOutcome.firstTry);
      expect(() => s.submit(line(0, 0, 1, 1)), throwsStateError);
    });

    test('a failed stroke stays current and counts failures', () {
      final s = TraceLetterSession(letterT);
      expect(s.submit(line(0.15, 0.9, 0.85, 0.9)), isFalse);
      expect(s.strokeIndex, 0);
      expect(s.failuresOn(0), 1);
    });

    test('three failures on one stroke make the letter a retry', () {
      final s = TraceLetterSession(letterT);
      for (var i = 0; i < 3; i++) {
        s.submit(line(0.15, 0.9, 0.85, 0.9));
      }
      s.submit(line(0.15, 0.1, 0.85, 0.1));
      s.submit(line(0.5, 0.1, 0.5, 0.9));
      expect(s.outcome, AnswerOutcome.retry);
    });
  });

  test('buildTraceRound picks 3 different new letters for a fresh player', () {
    final letters = [
      for (final c in 'ABCDEFGHIJ'.split('')) LetterItem(char: c, exampleWord: c, exampleEmoji: '⭐', strokes: letterT.strokes),
    ];
    for (var seed = 0; seed < 20; seed++) {
      final round = buildTraceRound(letters: letters, stats: const <String, ItemStat>{}, picker: QuestionPicker(Random(seed)));
      expect(round, hasLength(3));
      expect(round.map((l) => l.char).toSet(), hasLength(3));
    }
    expect(traceKey(letters.first), 'trace_en_upper:A');
  });
}
```
(Nếu `LetterItem` không có constructor const với `strokes`, thêm tham số `this.strokes = const []` vào constructor const.)

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `trace_logic.dart`**
```dart
import 'dart:math';

import '../../../core/content/models.dart';
import '../../../core/content/strokes.dart';
import '../../../core/progress/item_stat.dart';
import '../../../core/progress/question_picker.dart';

const kTraceTolerance = 0.12;
const kMinCoverage = 0.8;
const kMinPrecision = 0.7;

class StrokeScore {
  const StrokeScore(this.coverage, this.precision);

  final double coverage;
  final double precision;

  bool get passed => coverage >= kMinCoverage && precision >= kMinPrecision;
}

double _distToSegment(TracePoint p, TracePoint a, TracePoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return p.distanceTo(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return p.distanceTo(TracePoint(a.x + t * dx, a.y + t * dy));
}

StrokeScore scoreStroke(List<TracePoint> target, List<TracePoint> drawn, {double tolerance = kTraceTolerance}) {
  if (drawn.length < 2 || target.isEmpty) return const StrokeScore(0, 0);
  double distToDrawn(TracePoint p) {
    var best = double.infinity;
    for (var i = 1; i < drawn.length; i++) {
      best = min(best, _distToSegment(p, drawn[i - 1], drawn[i]));
    }
    return best;
  }

  double distToTarget(TracePoint p) => target.map(p.distanceTo).reduce(min);
  final covered = target.where((p) => distToDrawn(p) <= tolerance).length;
  final precise = drawn.where((p) => distToTarget(p) <= tolerance).length;
  return StrokeScore(covered / target.length, precise / drawn.length);
}

String traceKey(LetterItem l) => 'trace_en_upper:${l.char}';

class TraceLetterSession {
  TraceLetterSession(this.letter)
      : targets = [for (final s in letter.strokes) s.sample()],
        _failures = List.filled(letter.strokes.length, 0);

  final LetterItem letter;
  final List<List<TracePoint>> targets;
  final List<int> _failures;
  int _stroke = 0;

  int get strokeIndex => _stroke;
  bool get isDone => _stroke >= targets.length;
  int failuresOn(int stroke) => _failures[stroke];

  /// Scores [drawn] against the current stroke; true when it passes.
  bool submit(List<TracePoint> drawn) {
    if (isDone) throw StateError('letter already traced');
    if (scoreStroke(targets[_stroke], drawn).passed) {
      _stroke++;
      return true;
    }
    _failures[_stroke]++;
    return false;
  }

  AnswerOutcome get outcome => _failures.any((f) => f >= 3) ? AnswerOutcome.retry : AnswerOutcome.firstTry;
}

List<LetterItem> buildTraceRound({
  required List<LetterItem> letters,
  required Map<String, ItemStat> stats,
  required QuestionPicker picker,
  int count = 3,
  int maxNew = 3,
}) {
  final byKey = {for (final l in letters) traceKey(l): l};
  return [for (final k in picker.pick(candidates: byKey.keys.toList(), stats: stats, count: count, maxNew: maxNew)) byKey[k]!];
}
```
Lưu ý: `QuestionPicker` không lặp liền nhau nhưng có thể lặp không liền (A, B, A) khi chỉ còn ít ứng viên mới — test "3 chữ khác nhau" đúng với `maxNew: 3` và ≥ 4 chữ; nếu fail vì picker có thể chọn lại chữ mới đã dùng, sửa `buildTraceRound` để bỏ chữ đã chọn khỏi `candidates` ở các lần chọn sau (gọi `pick` từng chữ một), không sửa test.

- [ ] **Step 4: Chạy test, analyze** → xanh. **Commit** — `feat: stroke scoring and trace session logic`

---

### Task 3: Câu "Let's write …" và giọng

**Files:**
- Modify: `content/phrases.json` (+ version), `content/manifest.json`, `lib/core/content/content_validator.dart` (`requiredPhraseIds`), `lib/core/voice/utterances.dart` (`UtteranceKind.trace`), `test/content/voice_coverage_test.dart`, `test/core/voice/utterances_test.dart`, `content/audio/*`
- Interfaces: `UtteranceKind { fixed, vocab, trace, letters }`; `tracePhraseIds = ['trace_prompt']`.

- [ ] **Step 1:** Thêm phrase `{ "id": "trace_prompt", "lang": "en", "text": "Let's write {letter}!", "group": "instruction" }`; tăng version `phrases.json` (3) và manifest; thêm `'trace_prompt'` vào `requiredPhraseIds`.
- [ ] **Step 2:** `enumerateUtterances`: bỏ `trace_prompt` khỏi vòng `fixed` (thêm vào danh sách loại trừ cùng `vocabPhraseIds`/`letterPhraseIds`); **trước** vòng `letters`, thêm vòng `trace`: với mỗi chữ `add('trace_prompt', {'letter': l.char}, UtteranceKind.trace)` và `add('letter_example', {'letter': l.char, 'word': l.exampleWord}, UtteranceKind.trace)` (để `letter_example` thành bắt buộc vì trò tô chữ dùng nó).
- [ ] **Step 3:** Cập nhật test: `utterances_test.dart` — `trace` có 26 câu `trace_prompt` + 26 `letter_example`; `letters` còn `26*3`. `voice_coverage_test.dart` — chỉ `letters` là tùy chọn; `fixed`, `vocab`, `trace` bắt buộc. Test parity runtime (`test/core/voice/*parity*` từ v0.2.0) — thêm `trace_prompt` với `{'letter': l.char}` cho mọi chữ.
- [ ] **Step 4:** `dart run tool/gen_voice.dart --dry-run` (thấy ~26 câu mới), rồi `dart run tool/gen_voice.dart` (credentials ở `~/.config/xoai/vbee.env`; không in/đọc nội dung file). Nghe thử không bắt buộc; `ffprobe` một clip mới.
- [ ] **Step 5:** `flutter test`, `flutter analyze --no-fatal-infos`, `dart run tool/validate_content.dart` → xanh. **Commit** — `feat: trace prompts and their voice clips`

---

### Task 4: Màn chơi ✏️

**Files:**
- Create: `lib/features/games/trace/trace_pad.dart`, `lib/features/games/trace/trace_screen.dart`
- Modify: `lib/features/home/home_screen.dart` (✏️ → `TraceScreen`)
- Test: `test/features/trace/trace_screen_test.dart`, `test/features/home/home_screen_test.dart` (✏️ mở `TraceScreen`; bỏ/cập nhật test coi ✏️ là "sắp có" — dùng 🗣️ thay)

**Interfaces:**
- Consumes: Task 1–3; `ExampleCard` (`lib/features/games/find_letter/example_card.dart`); providers, `rewardStateProvider`, `RewardScreen`, `SessionRecord`, `dayKey`, widget dùng chung. Khuôn `VocabScreen` (`lib/features/games/vocab/vocab_screen.dart`): `_guard`, `_finishing`, `PopScope` (+ back gesture nói `go_home`), 🏠 nói `go_home`, spinner có `PopScope(canPop: _letters == null)`, `_finish` lưu phiên + `completeRound` + `pushReplacement(RewardScreen)`.
- Produces:
  - `TracePad({required List<List<TracePoint>> strokes, required int current, required ValueChanged<List<TracePoint>> onStrokeDrawn, bool enabled = true})` — vuông, `Key('trace-pad')`; nhận pan → điểm chuẩn hóa (vị trí / cạnh); gọi `onStrokeDrawn` khi thả tay (nếu ≥ 2 điểm); vẽ: nét đã xong (liền, `IceColors.deep`, dày 0,07·cạnh, bo tròn), nét hiện tại (nét đứt phát sáng `IceColors.frost` + chấm tròn số thứ tự ở điểm đầu + mũi tên nhỏ ở ~25% chiều dài theo hướng nét), nét chưa tới (đứt, xám nhạt), vệt đang tô (trắng-xanh dày, có glow). Sau khi `onStrokeDrawn` được gọi, vệt đang tô được xóa.
  - `TraceScreen`.

- [ ] **Step 1: Test (failing)** — `test/features/trace/trace_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/content_repository.dart';
import 'package:xoai_castle/core/content/file_content_source.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/content/strokes.dart';
import 'package:xoai_castle/features/games/trace/trace_screen.dart';
import 'package:xoai_castle/features/reward/reward_screen.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

final _prompt = RegExp(r"^Let's write (\w)!$");

List<String> asked(FakeTts tts) => [
      for (final t in tts.texts)
        if (_prompt.hasMatch(t)) _prompt.firstMatch(t)![1]!,
    ];

Future<void> drawPoints(WidgetTester tester, List<TracePoint> pts) async {
  final rect = tester.getRect(find.byKey(const Key('trace-pad')));
  Offset at(TracePoint p) => rect.topLeft + Offset(p.x * rect.width, p.y * rect.height);
  final g = await tester.startGesture(at(pts.first));
  for (final p in pts.skip(1)) {
    await g.moveTo(at(p));
  }
  await g.up();
  await tester.pump();
}

void main() {
  late ContentBundle content;
  setUpAll(() async => content = await ContentRepository(FileContentSource('content')).load());

  LetterItem letter(String c) => content.lettersEn.firstWhere((l) => l.char == c);

  testWidgets('tracing every stroke of three letters ends on the reward screen', (tester) async {
    final tts = FakeTts();
    final rewards = MemoryRewardStore();
    final sessions = MemorySessionStore();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen(), rewards: rewards, sessions: sessions));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      final c = asked(tts);
      expect(c, hasLength(i + 1), reason: 'letter ${i + 1}');
      for (final s in letter(c.last).strokes) {
        await drawPoints(tester, s.sample(step: 0.05));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RewardScreen), findsOneWidget);
    expect(find.text('+8 ❄️'), findsOneWidget);
    expect(sessions.records.single.game, 'trace');
  });

  testWidgets('a stroke drawn in the wrong place says try again and stays', (tester) async {
    final tts = FakeTts();
    await tester.pumpWidget(testApp(content: content, tts: tts, home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    await drawPoints(tester, [for (var i = 0; i <= 20; i++) TracePoint(0.02 + i * 0.001, 0.02)]);
    expect(tts.texts.where((t) => t == 'Try again!' || t == 'Thử lại nha con!'), hasLength(1));
    expect(asked(tts), hasLength(1));
  });

  testWidgets('fits a 360x640 phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const TraceScreen()));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final pad = tester.getRect(find.byKey(const Key('trace-pad')));
    expect(pad.width, greaterThanOrEqualTo(280));
  });
}
```
(Lưu ý: chữ đầu tiên mỗi chữ dùng `letter_example` khi xong; tiếng "Try again" lấy từ nhóm `try_again`. Nếu pan recognizer cần vượt ngưỡng kéo trước khi nhận điểm, điểm đầu vẫn phải được ghi nhận: dùng `onPanStart(details.localPosition)`.)

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `trace_pad.dart`** — `StatefulWidget` giữ `_drawing` (List<TracePoint>); `LayoutBuilder` → `side = min(maxWidth, maxHeight)`; `GestureDetector(onPanStart/onPanUpdate/onPanEnd)` bọc `CustomPaint(size: Size.square(side), painter: _TracePainter(...))` với `key: const Key('trace-pad')` trên `SizedBox.square(side)`; điểm = `local / side` clamp 0–1; `onPanEnd`: nếu `_drawing.length >= 2` → `widget.onStrokeDrawn(List.of(_drawing))`, rồi xóa `_drawing`. Painter: vẽ nền trắng bo góc 24; nét theo mô tả ở Interfaces (đường đứt: vẽ các đoạn xen kẽ theo điểm mẫu, ví dụ 2 điểm vẽ/2 điểm bỏ); chấm số: hình tròn `IceColors.deep` bán kính 0,045·cạnh + số trắng (`TextPainter`); mũi tên: tam giác nhỏ tại điểm ~25% theo hướng (điểm i+1 − điểm i). `shouldRepaint` khi strokes/current/drawing đổi.

- [ ] **Step 4: `trace_screen.dart`** — như `VocabScreen` nhưng:
  - `_start`: `_stats = loadByPrefix('trace_en_')`; `_letters = buildTraceRound(letters: content.lettersEn, stats: _stats, picker: QuestionPicker(random))`; `_index = 0`; `_session = TraceLetterSession(_letters[0])`; `_ask()` nói `trace_prompt` với `{'letter': char}`.
  - Header: 🏠 + "`${_index + 1}/3`". Elsa (chạm → nói lại prompt nếu không `_busy`). Dưới: `Expanded(child: Center(child: Padding(16, TracePad(...))))`; khi đang ăn mừng hiện `ExampleCard(item: letter)` chồng giữa.
  - `onStrokeDrawn(drawn)`: nếu `_busy` bỏ qua; `ok = _session.submit(drawn)`; `setState`; nếu `!ok` → `sayGroup('try_again')`; nếu `_session.isDone` → `_busy = true`, hiện thẻ ví dụ, lưu stat (`traceKey`, `_session.outcome`), `Future.wait([say('letter_example', vars: {'letter': c, 'word': exampleWord}), delay 800ms])`, rồi sang chữ sau (`_index++`, phiên mới, `_ask()`) hoặc `_finish()` (game `'trace'`, `firstTryCount` = số chữ `firstTry`).
  - `_finishing` = đang ăn mừng chữ cuối.
- [ ] **Step 5: Màn chính** — `const _GameEntry('✏️', 'game_trace')` → `_GameEntry('✏️', 'game_trace', (_) => const TraceScreen())`. Sửa test home: test "coming soon" dùng 🗣️ ("Nói chuyện với Elsa") thay ✏️; thêm test ✏️ mở `TraceScreen`.
- [ ] **Step 6:** `flutter test`, `flutter analyze --no-fatal-infos`, `flutter build apk --debug` → xanh. **Commit** — `feat: letter tracing game`

---

### Task 5: Đặt lại dữ liệu game

**Files:**
- Create: `lib/core/progress/progress_resetter.dart`
- Modify: `lib/app/providers.dart` (`progressResetterProvider`), `lib/features/parent/parent_screen.dart`, `test/support/fakes.dart` (`FakeProgressResetter`), `test/support/test_app.dart` (tham số `ProgressResetter? resetter`, mặc định fake)
- Test: `test/core/db/progress_resetter_test.dart`, `test/features/parent/parent_screen_test.dart` (thêm case)

**Interfaces:**
- Produces: `abstract interface class ProgressResetter { Future<void> resetProgress(); }`; `DriftProgressResetter(AppDatabase)`; `progressResetterProvider = Provider<ProgressResetter>((ref) => DriftProgressResetter(ref.watch(databaseProvider)))`; `FakeProgressResetter { int calls; Future<void> Function()? onReset; }`.

- [ ] **Step 1: Test (failing)**

`test/core/db/progress_resetter_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xoai_castle/core/content/models.dart';
import 'package:xoai_castle/core/db/database.dart';
import 'package:xoai_castle/core/profile/profile_store.dart';
import 'package:xoai_castle/core/progress/item_stat.dart';
import 'package:xoai_castle/core/progress/item_stats_store.dart';
import 'package:xoai_castle/core/progress/progress_resetter.dart';
import 'package:xoai_castle/core/rewards/reward_state.dart';
import 'package:xoai_castle/core/rewards/reward_store.dart';
import 'package:xoai_castle/core/session/session_store.dart';

void main() {
  test('reset clears progress and keeps the profile', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profile = DriftProfileStore(db);
    await profile.loadNames(const ProfileDefaults(nameEn: 'An', nameVi: 'Xoài', dailyLimitMin: 20));
    await profile.setShowFindLetter(true);
    await DriftItemStatsStore(db).save(const ItemStat(key: 'word:lion', mastery: 3));
    await DriftSessionStore(db).add(SessionRecord(
        date: '2026-11-02', game: 'vocab', startedAt: DateTime(2026, 11, 2, 9), durationSec: 60, correct: 8, total: 8));
    await DriftRewardStore(db).save(const RewardState(
        snowflakesTotal: 120, castleLevel: 4, streakDays: 3, dailyQuestDate: '2026-11-02', dailyRoundsDone: 2));

    await DriftProgressResetter(db).resetProgress();

    expect(await DriftItemStatsStore(db).loadByPrefix(''), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    final r = await DriftRewardStore(db).load();
    expect([r.snowflakesTotal, r.castleLevel, r.streakDays, r.dailyRoundsDone], [0, 1, 0, 0]);
    expect(r.dailyQuestDate, isNull);
    expect(await profile.showFindLetter(), isTrue);
    expect((await profile.loadNames(const ProfileDefaults(nameEn: 'X', nameVi: 'Y', dailyLimitMin: 1))).vi, 'Xoài');
  });
}
```
Thêm vào `parent_screen_test.dart`:
```dart
  testWidgets('reset asks for confirmation; cancel keeps data', (tester) async {
    final resetter = FakeProgressResetter();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const ParentScreen(), resetter: resetter));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Đặt lại dữ liệu game'), 200);
    await tester.tap(find.text('Đặt lại dữ liệu game'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Xóa toàn bộ tiến độ của Xoài? Không khôi phục được.'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(resetter.calls, 0);
  });

  testWidgets('confirming reset clears progress and refreshes the snowflakes', (tester) async {
    final rewards = MemoryRewardStore(const RewardState(snowflakesTotal: 50, castleLevel: 3));
    final resetter = FakeProgressResetter()..onReset = () async => rewards.state = const RewardState();
    await tester.pumpWidget(testApp(content: content, tts: FakeTts(), home: const HomeScreen(), rewards: rewards, resetter: resetter));
    await tester.pump();
    expect(find.text('❄️ 50'), findsOneWidget);
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Đặt lại dữ liệu game'), 200);
    await tester.tap(find.text('Đặt lại dữ liệu game'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Xóa'));
    await tester.pump(const Duration(seconds: 1));
    expect(resetter.calls, 1);
    expect(find.byType(ParentScreen), findsNothing);
    expect(find.text('❄️ 0'), findsOneWidget);
  });
```

- [ ] **Step 2: Chạy, xác nhận fail.**

- [ ] **Step 3: `progress_resetter.dart`**
```dart
import 'package:drift/drift.dart';

import '../db/database.dart';

abstract interface class ProgressResetter {
  /// Deletes all learning progress and rewards; keeps the profile (names, switches).
  Future<void> resetProgress();
}

class DriftProgressResetter implements ProgressResetter {
  DriftProgressResetter(this._db);

  final AppDatabase _db;

  @override
  Future<void> resetProgress() => _db.transaction(() async {
        await _db.delete(_db.itemStats).go();
        await _db.delete(_db.sessions).go();
        await _db.into(_db.rewards).insertOnConflictUpdate(RewardsCompanion(
              id: const Value(1),
              snowflakesTotal: const Value(0),
              castleLevel: const Value(1),
              streakDays: const Value(0),
              lastPlayDate: const Value(null),
              dailyQuestDate: const Value(null),
              dailyRoundsDone: const Value(0),
            ));
      });
}
```
- [ ] **Step 4: UI** — cuối `ListView` của `ParentScreen`:
```dart
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Đặt lại dữ liệu game', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Xóa ❄️, lâu đài, mức thuộc và lịch sử chơi; giữ tên và cài đặt'),
            onTap: () => _confirmReset(context, ref),
          ),
```
và:
```dart
Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Đặt lại dữ liệu'),
      content: const Text('Xóa toàn bộ tiến độ của Xoài? Không khôi phục được.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await ref.read(progressResetterProvider).resetProgress();
  ref.invalidate(rewardStateProvider);
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
}
```
(Dùng tên bé từ `profile` nếu sẵn có trong provider; nếu không, chuỗi cố định "Xoài" như trên là chấp nhận được vì app chỉ có một bé.)
- [ ] **Step 5:** `flutter test`, `flutter analyze --no-fatal-infos` → xanh. **Commit** — `feat: reset game progress from the parent area`

---

### Task 6 (controller): Phát hành v0.3.0
- [ ] Review toàn nhánh; sửa phát hiện.
- [ ] Build release cục bộ `--build-name=0.2.9 --build-number=299`, cài thử lên điện thoại (giữ dữ liệu), kiểm tra tô chữ bằng tay.
- [ ] `version: 0.3.0+3`; PR → CI → merge → tag `v0.3.0` → Release; cập nhật qua app.
