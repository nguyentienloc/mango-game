import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/updater/app_updater.dart';

/// Downloads the release APK with progress, then opens the Android installer.
class UpdateDownloadDialog extends ConsumerStatefulWidget {
  const UpdateDownloadDialog({super.key, required this.release});

  final ReleaseInfo release;

  @override
  ConsumerState<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
  final _cancel = CancelToken();
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    if (!_cancel.isCancelled) _cancel.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = await ref.read(appUpdaterProvider).download(
        widget.release,
        dir.path,
        cancelToken: _cancel,
        onProgress: (received, total) {
          if (mounted && total > 0) setState(() => _progress = received / total);
        },
      );
      if (!mounted || _cancel.isCancelled) return;
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (!mounted) return;
      if (result.type == ResultType.done) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = 'Không mở được trình cài đặt: ${result.message}');
      }
    } catch (e) {
      if (mounted && !_cancel.isCancelled) setState(() => _error = 'Tải bản cập nhật lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return AlertDialog(
      title: Text('Cập nhật ${widget.release.version}'),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(progress == null ? 'Đang tải…' : 'Đang tải ${(progress * 100).round()}%'),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () {
            _cancel.cancel();
            Navigator.of(context).pop();
          },
          child: Text(_error != null ? 'Đóng' : 'Hủy'),
        ),
      ],
    );
  }
}
