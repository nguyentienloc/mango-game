import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'story_grid_screen.dart';
import 'story_library.dart';
import 'story_models.dart';
import 'story_run.dart';

const _defaultMinutes = 15;
const _defaultCount = 2;

enum _LimitKind { count, time }

/// The parent sets up one story-time sitting: topics, a count or time limit,
/// and listen-only or video. Starts from the last setup; **Bắt đầu** saves it
/// and replaces this screen with the grid (back does not come here again).
class StorySetupScreen extends ConsumerStatefulWidget {
  const StorySetupScreen({super.key});

  @override
  ConsumerState<StorySetupScreen> createState() => _StorySetupScreenState();
}

class _StorySetupScreenState extends ConsumerState<StorySetupScreen> {
  StoryLibrary? _library;
  Object? _loadError;
  bool _starting = false;

  Set<StoryTopic> _topics = {};
  _LimitKind _kind = _LimitKind.count;
  int _count = _defaultCount;
  int _minutes = _defaultMinutes;
  StoryOverrun _overrun = StoryOverrun.finish;
  StoryViewMode _mode = StoryViewMode.listen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final last = await ref.read(storyStoreProvider).lastSetup();
      final library = await ref.read(storyLibraryProvider.future);
      if (!mounted) return;
      setState(() {
        _library = library;
        _topics = last.topics.intersection(library.topicsWithStories);
        _mode = last.mode;
        switch (last.limit) {
          case CountLimit(:final stories):
            _kind = _LimitKind.count;
            _count = stories;
          case TimeLimit(:final duration, :final overrun):
            _kind = _LimitKind.time;
            _minutes = duration.inMinutes;
            _overrun = overrun;
        }
      });
    } catch (e, st) {
      debugPrint('Story setup load error: $e\n$st');
      if (mounted) setState(() => _loadError = e);
    }
  }

  StorySetup get _setup => StorySetup(
    topics: _topics,
    limit: switch (_kind) {
      _LimitKind.count => CountLimit(_count),
      _LimitKind.time => TimeLimit(Duration(minutes: _minutes), _overrun),
    },
    mode: _mode,
  );

  Future<void> _start(StoryLibrary library) async {
    if (_starting) return;
    _starting = true;
    final setup = _setup;
    final navigator = Navigator.of(context);
    try {
      await ref.read(storyStoreProvider).saveSetup(setup);
    } catch (e, st) {
      // Not remembering the choice must not stop story time.
      debugPrint('Story setup save error: $e\n$st');
    }
    if (!mounted) return;
    // Built here, once: its clock starts now and the grid owns and disposes it.
    final run = StoryRun(setup: setup, library: library);
    await navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => StoryGridScreen(run: run)));
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chuyện')),
      body: switch ((library, _loadError)) {
        (_, final Object _) => const Center(child: Text('Không tải được danh sách truyện, thử lại nhé')),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final StoryLibrary lib, _) => _form(lib),
      },
    );
  }

  Widget _form(StoryLibrary library) {
    final available = [
      for (final t in StoryTopic.values)
        if (library.topicsWithStories.contains(t)) t,
    ];
    final empty = library.visible().isEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (empty)
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.orange),
            title: Text('Chưa có truyện. Vào khu bố mẹ → Truyện để thêm.'),
          )
        else ...[
          const _Header('Chủ đề'),
          _wrap([
            FilterChip(
              label: const Text('Tất cả'),
              selected: _topics.isEmpty,
              onSelected: (_) => setState(() => _topics = {}),
            ),
            for (final t in available)
              FilterChip(
                label: Text(t.label),
                selected: _topics.contains(t),
                onSelected: (on) => setState(() => _topics = on ? {..._topics, t} : ({..._topics}..remove(t))),
              ),
          ]),
          const _Header('Giới hạn'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_LimitKind>(
              segments: const [
                ButtonSegment(value: _LimitKind.count, label: Text('Số truyện')),
                ButtonSegment(value: _LimitKind.time, label: Text('Thời gian')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
          ),
          const SizedBox(height: 8),
          if (_kind == _LimitKind.count)
            _wrap([
              for (final n in storyCountOptions)
                ChoiceChip(label: Text('$n'), selected: _count == n, onSelected: (_) => setState(() => _count = n)),
            ])
          else ...[
            _wrap([
              for (final m in storyMinuteOptions)
                ChoiceChip(
                  label: Text('$m phút'),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ]),
            RadioGroup<StoryOverrun>(
              groupValue: _overrun,
              onChanged: (v) => setState(() => _overrun = v ?? _overrun),
              child: const Column(
                children: [
                  RadioListTile(
                    value: StoryOverrun.finish,
                    title: Text('Nghe hết truyện đang dở'),
                    subtitle: Text('Lố tối đa 10 phút'),
                  ),
                  RadioListTile(
                    value: StoryOverrun.stopNow,
                    title: Text('Dừng ngay khi hết giờ'),
                    subtitle: Text('Nhỏ dần tiếng rồi dừng'),
                  ),
                ],
              ),
            ),
          ],
          const _Header('Chế độ'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<StoryViewMode>(
              segments: const [
                ButtonSegment(value: StoryViewMode.listen, label: Text('🌙 Chỉ nghe')),
                ButtonSegment(value: StoryViewMode.watch, label: Text('🎬 Xem video')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.single),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('story-start'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: empty ? null : () => _start(library),
            child: const Text('Bắt đầu', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _wrap(List<Widget> chips) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(spacing: 8, runSpacing: 4, children: chips),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
