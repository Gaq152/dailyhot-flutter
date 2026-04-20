import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/update_download_state.dart';
import '../../data/services/update_service.dart';
import '../providers/settings_provider.dart';
import '../providers/update_download_provider.dart';

/// 发现新版本对话框
///
/// - 主按钮会根据 [updateDownloadProvider] 当前状态切换：
///   - 目标版本已下载完成 → "立即安装"
///   - 其他情况 → "下载并安装"
/// - "稍后" 将版本信息写入 [settingsProvider]，供设置页后续跟进
Future<void> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateInfo info, {
  bool showPublishedAt = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _UpdateDialog(info: info, showPublishedAt: showPublishedAt),
  );
}

class _UpdateDialog extends ConsumerWidget {
  final UpdateInfo info;
  final bool showPublishedAt;

  const _UpdateDialog({required this.info, required this.showPublishedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(updateDownloadProvider);
    final isAlreadyDownloaded =
        downloadState is UpdateCompleted &&
        downloadState.version == info.version;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.celebration, color: Colors.orange.shade600, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('发现新版本', style: TextStyle(fontSize: 20))),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'v${info.version}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.new_releases,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '更新内容',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info.changelog,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              if (showPublishedAt) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '发布于 ${_formatDate(info.publishedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref
                .read(settingsProvider.notifier)
                .setPendingUpdate(
                  info.version,
                  info.downloadUrl,
                  info.changelog,
                );
          },
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(settingsProvider.notifier).clearPendingUpdate();

            final notifier = ref.read(updateDownloadProvider.notifier);
            if (isAlreadyDownloaded) {
              await notifier.install();
            } else {
              await notifier.download(info);
            }
          },
          icon: Icon(
            isAlreadyDownloaded ? Icons.install_mobile : Icons.download,
            size: 18,
          ),
          label: Text(isAlreadyDownloaded ? '立即安装' : '下载并安装'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
