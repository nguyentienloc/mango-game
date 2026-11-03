import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/stories/story_store.dart';
import '../story/story_library.dart';
import '../story/story_models.dart';
import 'add_story_sheet.dart';

/// The parent's story list, by topic: bundled stories can be hidden, added
/// ones deleted; ➕ adds one from a YouTube link.
class StoriesManageScreen extends ConsumerWidget {
  const StoriesManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(storyLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Truyện')),
      floatingActionButton: FloatingActionButton(
        key: const Key('story-add'),
        tooltip: 'Thêm truyện',
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: switch (library) {
        AsyncValue(:final value?) => _list(context, value),
        AsyncValue(:final error?) => Center(child: Text('Không tải được danh sách truyện: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(BuildContext context, StoryLibrary library) {
    if (library.all.isEmpty) {
      return const Center(child: Text('Chưa có truyện. Bấm ➕ để thêm từ link YouTube.'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final topic in StoryTopic.values)
          if (library.all.any((s) => s.topic == topic)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(topic.label, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final s in library.all)
              if (s.topic == topic) _row(context, library, s),
          ],
      ],
    );
  }

  Widget _row(BuildContext context, StoryLibrary library, Story s) {
    final length = s.duration == null ? '—' : formatStoryLength(s.duration!);
    return ListTile(
      key: Key('story-row-${s.videoId}'),
      leading: SizedBox(
        key: Key('story-thumb-${s.videoId}'),
        width: 64,
        height: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            s.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Text('📖')),
            ),
          ),
        ),
      ),
      title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('$length · ${s.userAdded ? 'Tự thêm' : 'Có sẵn'}'),
      trailing: s.userAdded
          ? IconButton(
              key: Key('story-delete-${s.videoId}'),
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, s),
            )
          : Switch(
              key: Key('story-visible-${s.videoId}'),
              value: !library.isHidden(s),
              onChanged: (visible) => _change(context, (store) => store.setHidden(s.id, !visible)),
            ),
    );
  }

  Future<void> _delete(BuildContext context, Story s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa truyện'),
        content: Text('Xóa "${s.title}" khỏi danh sách?'),
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
    await _change(context, (store) => store.deleteUserStory(s.videoId));
  }

  Future<void> _add(BuildContext context) async {
    // Taken before the await: still valid if this screen is gone by then.
    final container = ProviderScope.containerOf(context, listen: false);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 1, child: AddStorySheet()),
    );
    if (added == true) container.invalidate(storyLibraryProvider);
  }

  /// Runs one store edit, then reloads the library; a failure is shown, not thrown.
  Future<void> _change(BuildContext context, Future<void> Function(StoryStore store) edit) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await edit(container.read(storyStoreProvider));
    } catch (e, st) {
      debugPrint('Story list edit error: $e\n$st');
      messenger.showSnackBar(const SnackBar(content: Text('Không lưu được, thử lại nhé')));
    }
    container.invalidate(storyLibraryProvider);
  }
}
