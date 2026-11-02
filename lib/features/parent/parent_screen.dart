import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/reward_controller.dart';
import '../../app/show_find_letter_controller.dart';
import '../../app/voice_speeds_controller.dart';
import '../../core/content/vocab.dart';
import '../../core/profile/profile_store.dart';
import '../../core/updater/app_updater.dart';
import 'update_download_dialog.dart';

class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingVoicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khu bố mẹ')),
      body: ListView(
        children: [
          if (missing.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Colors.orange),
              title: Text('Máy chưa có giọng đọc: ${missing.map(_localeName).join(', ')}'),
              subtitle: const Text(
                'Cài đặt → Hệ thống → Ngôn ngữ → Chuyển văn bản thành giọng nói → Google → cài dữ liệu giọng',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Phiên bản app'),
            subtitle: Text(ref.watch(appVersionProvider)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.abc),
            title: const Text('Hiện trò Tìm chữ cái'),
            subtitle: const Text('Trò 🎈 tìm chữ cái tiếng Anh, dành cho khi bé đã thuộc mặt chữ'),
            value: ref.watch(showFindLetterProvider).value ?? false,
            onChanged: (v) => ref.read(showFindLetterProvider.notifier).set(v),
          ),
          const _SpeedSection(),
          const UpdateTile(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Đặt lại dữ liệu game', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Xóa ❄️, lâu đài, mức thuộc và lịch sử chơi; giữ tên và cài đặt'),
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  // Taken before any await: it stays valid even if this screen is gone by then.
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
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
  try {
    await container.read(progressResetterProvider).resetProgress();
  } catch (e, st) {
    debugPrint('Reset error: $e\n$st');
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Không đặt lại được dữ liệu, thử lại nhé')));
    }
    return;
  }
  container.invalidate(rewardStateProvider);
  if (context.mounted) {
    navigator.popUntil((r) => r.isFirst);
    container.read(voiceProvider).say('greet_vi');
  }
}

class _SpeedSection extends ConsumerWidget {
  const _SpeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speeds = ref.watch(voiceSpeedsProvider).value ?? const VoiceSpeeds();
    final controller = ref.read(voiceSpeedsProvider.notifier);

    void sample(String lang) {
      final voice = ref.read(voiceProvider);
      if (lang == 'vi') {
        voice.say('greet_vi');
      } else {
        final lion = ref.read(contentProvider).vocab.firstWhere((w) => w.id == 'lion');
        voice.say('vocab_prompt', vars: vocabVars(lion));
      }
    }

    Widget tile(String title, String lang) {
      final value = speeds.forLang(lang);
      VoiceSpeeds withSpeed(double v) => lang == 'vi' ? speeds.copyWith(vi: v) : speeds.copyWith(en: v);
      return ListTile(
        leading: const Icon(Icons.speed),
        title: Text(title),
        subtitle: Slider(
          min: VoiceSpeeds.min,
          max: VoiceSpeeds.max,
          divisions: 14,
          value: value,
          label: _speedLabel(value),
          onChanged: (v) => controller.preview(withSpeed(_round(v))),
          onChangeEnd: (v) async {
            await controller.set(withSpeed(_round(v)));
            if (!context.mounted) return;
            sample(lang);
          },
        ),
        trailing: Text(_speedLabel(value)),
      );
    }

    return Column(
      children: [
        tile('Tốc độ đọc tiếng Anh', 'en'),
        tile('Tốc độ đọc tiếng Việt', 'vi'),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () async {
                await controller.set(const VoiceSpeeds());
                if (!context.mounted) return;
                sample('en');
              },
              child: const Text('Mặc định'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slider steps are multiples of 0.05; rounding removes float noise (0.9500000001).
double _round(double v) => (v * 100).round() / 100;

/// "0,85×" — Vietnamese decimal comma.
String _speedLabel(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')}×';

String _localeName(String locale) => locale == 'vi-VN' ? 'Tiếng Việt' : 'Tiếng Anh';

class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget retry(String message) => ListTile(
      leading: const Icon(Icons.error_outline, color: Colors.orange),
      title: Text(message),
      trailing: TextButton(onPressed: () => ref.invalidate(updateCheckProvider), child: const Text('Kiểm tra lại')),
    );

    return ref
        .watch(updateCheckProvider)
        .when(
          loading: () => ListTile(
            leading: const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: const Text('Đang kiểm tra cập nhật…'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(updateCheckProvider),
              child: const Text('Kiểm tra lại'),
            ),
          ),
          error: (e, _) => retry('Lỗi kiểm tra cập nhật: $e'),
          data: (check) => switch (check) {
            UpToDate() => ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Đang dùng bản mới nhất'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(updateCheckProvider),
                child: const Text('Kiểm tra lại'),
              ),
            ),
            CheckFailed(:final message) => retry(message),
            UpdateAvailable(:final release) => ListTile(
              leading: const Icon(Icons.system_update, color: Colors.red),
              title: Text('Có bản mới ${release.version}'),
              subtitle: Text('${(release.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'),
              trailing: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => UpdateDownloadDialog(release: release),
                ),
                child: const Text('Cập nhật'),
              ),
            ),
          },
        );
  }
}
