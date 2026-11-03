import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../story/oembed_client.dart';
import '../story/story_models.dart';
import '../story/story_player.dart';
import '../story/youtube_link.dart';

/// Adds a story from a YouTube link: checks the link, asks YouTube (oEmbed)
/// whether it exists and may be embedded, then previews it. **Lưu** is allowed
/// once the preview has really played (that is also when its length is read);
/// a preview that fails cannot be saved. Pops `true` after saving.
class AddStorySheet extends ConsumerStatefulWidget {
  const AddStorySheet({super.key});

  @override
  ConsumerState<AddStorySheet> createState() => _AddStorySheetState();
}

class _AddStorySheetState extends ConsumerState<AddStorySheet> {
  final _link = TextEditingController();
  final _title = TextEditingController();

  String? _error;
  bool _checking = false;
  bool _saving = false;

  /// Bumped on every check or reset so a late answer for an older link is dropped.
  int _attempt = 0;

  // The preview, once the link passed the checks.
  String? _videoId;
  StoryPlayerController? _player;
  StreamSubscription<StoryPlayerState>? _sub;
  StoryTopic _topic = StoryTopic.fairyVi;
  bool _played = false;
  bool _playFailed = false;
  Duration? _duration;

  @override
  void dispose() {
    _closePreview();
    _link.dispose();
    _title.dispose();
    super.dispose();
  }

  void _closePreview() {
    unawaited(_sub?.cancel());
    _sub = null;
    _player?.dispose();
    _player = null;
    _videoId = null;
    _played = false;
    _playFailed = false;
    _duration = null;
  }

  /// The link was edited: the preview no longer matches it.
  void _onLinkChanged(String _) {
    if (_videoId == null && _error == null && !_checking) return;
    _attempt++;
    setState(() {
      _closePreview();
      _checking = false;
      _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    _link.text = text;
    _onLinkChanged(text);
  }

  Future<void> _check() async {
    if (_checking) return;
    FocusScope.of(context).unfocus();
    final attempt = ++_attempt;
    setState(() {
      _closePreview();
      _error = null;
    });
    final id = parseYoutubeId(_link.text);
    if (id == null) {
      setState(() => _error = 'Link không hợp lệ');
      return;
    }
    setState(() => _checking = true);
    OEmbedResult result;
    try {
      final library = await ref.read(storyLibraryProvider.future);
      if (library.all.any((s) => s.videoId == id)) {
        if (mounted && attempt == _attempt) {
          setState(() {
            _checking = false;
            _error = 'Truyện đã có';
          });
        }
        return;
      }
      result = await ref.read(oembedClientProvider).fetch(id);
    } catch (e, st) {
      debugPrint('Add story check error: $e\n$st');
      result = const OEmbedFailed();
    }
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _checking = false;
      switch (result) {
        case OEmbedOk(:final title):
          _title.text = title;
          _openPreview(id);
        case OEmbedNotEmbeddable():
          _error = 'Video này không cho phát trong app';
        case OEmbedNotFound():
          _error = 'Không tìm thấy video';
        case OEmbedFailed():
          _error = 'Không kết nối được, thử lại nhé';
      }
    });
  }

  void _openPreview(String id) {
    final player = ref.read(storyPlayerFactoryProvider)(controls: true);
    _videoId = id;
    _player = player;
    _sub = player.states.listen((s) {
      if (!mounted || _player != player) return;
      switch (s) {
        case StoryPlayerState.playing:
          setState(() => _played = true);
          if (_duration == null) unawaited(_readDuration(player));
        case StoryPlayerState.error:
          setState(() {
            _playFailed = true;
            _error = 'Video này không phát được';
          });
        case StoryPlayerState.loading || StoryPlayerState.paused || StoryPlayerState.ended:
          break;
      }
    });
    unawaited(player.load(id));
  }

  Future<void> _readDuration(StoryPlayerController player) async {
    final d = await player.duration();
    if (!mounted || _player != player || d == null || d <= Duration.zero) return;
    setState(() => _duration = d);
  }

  bool get _canSave =>
      _videoId != null && !_playFailed && !_saving && (_played || _duration != null) && _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    final id = _videoId;
    if (id == null || !_canSave) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(storyStoreProvider)
          .addUserStory(
            Story(videoId: id, title: _title.text.trim(), topic: _topic, duration: _duration, userAdded: true),
          );
    } catch (e, st) {
      debugPrint('Add story save error: $e\n$st');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Không lưu được, thử lại nhé';
        });
      }
      return;
    }
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thêm truyện', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('story-link'),
              controller: _link,
              onChanged: _onLinkChanged,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link YouTube',
                hintText: 'https://youtu.be/…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('story-paste'),
                  tooltip: 'Dán',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: const Key('story-check'),
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kiểm tra'),
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  key: const Key('story-add-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (player != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(color: Colors.black, child: player.buildView()),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _playFailed
                    ? ''
                    : _played
                    ? 'Độ dài: ${_duration == null ? '—' : formatStoryLength(_duration!)}'
                    : 'Đang mở video để thử…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('story-title'),
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Tên truyện', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Chủ đề: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<StoryTopic>(
                      key: const Key('story-topic'),
                      isExpanded: true,
                      value: _topic,
                      items: [for (final t in StoryTopic.values) DropdownMenuItem(value: t, child: Text(t.label))],
                      onChanged: (t) => setState(() => _topic = t ?? _topic),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('story-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _canSave ? _save : null,
                child: const Text('Lưu'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
