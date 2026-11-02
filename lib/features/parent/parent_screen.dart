import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/updater/app_updater.dart';
import 'update_download_dialog.dart';

class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khu bố mẹ')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Phiên bản app'),
            subtitle: Text(ref.watch(appVersionProvider)),
          ),
          const UpdateTile(),
        ],
      ),
    );
  }
}

class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget retry(String message) => ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.orange),
          title: Text(message),
          trailing: TextButton(
            onPressed: () => ref.invalidate(updateCheckProvider),
            child: const Text('Kiểm tra lại'),
          ),
        );

    return ref.watch(updateCheckProvider).when(
          loading: () => const ListTile(
            leading: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Đang kiểm tra cập nhật…'),
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
