import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/update_download_state.dart';
import '../../data/services/update_service.dart';
import '../providers/update_download_provider.dart';

/// 应用内更新下载横幅
///
/// 跟随 [updateDownloadProvider] 状态展示不同 UI：
/// - Idle → 不显示
/// - Preparing → 蓝色横幅，转圈
/// - Downloading → 蓝色横幅，进度条 + 字节/百分比，右侧取消按钮
/// - Completed → 绿色横幅 + "立即安装"
/// - Failed → 橙色横幅 + "重试"/"关闭"
class UpdateDownloadBanner extends ConsumerWidget {
  /// 当失败横幅点击"重试"时使用的更新信息。
  /// 若为 null，失败时只显示"关闭"（主要在设置页传入 pending 更新时用）。
  final UpdateInfo? retryInfo;

  const UpdateDownloadBanner({super.key, this.retryInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateDownloadProvider);

    switch (state) {
      case UpdateIdle():
        return const SizedBox.shrink();
      case UpdatePreparing(:final version):
        return _Banner(
          color: Colors.blue.shade700,
          semanticsLabel: '准备下载 v$version',
          child: _PreparingContent(version: version),
        );
      case UpdateDownloading():
        return _Banner(
          color: Colors.blue.shade700,
          semanticsLabel: '下载中 ${(state.progress * 100).toStringAsFixed(0)}%',
          child: _DownloadingContent(
            state: state,
            onCancel: () => ref.read(updateDownloadProvider.notifier).cancel(),
          ),
        );
      case UpdateCompleted(:final version):
        return _Banner(
          color: Colors.green.shade700,
          semanticsLabel: 'v$version 下载完成',
          child: _CompletedContent(
            version: version,
            onInstall: () async {
              final ok = await ref
                  .read(updateDownloadProvider.notifier)
                  .install();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未获得安装权限，请在系统设置中允许')),
                );
              }
            },
          ),
        );
      case UpdateFailed():
        return _Banner(
          color: Colors.orange.shade800,
          semanticsLabel: '下载失败：${state.error.userMessage}',
          child: _FailedContent(
            failed: state,
            retryInfo: retryInfo,
            onRetry: retryInfo != null
                ? () => ref
                      .read(updateDownloadProvider.notifier)
                      .retry(retryInfo!)
                : null,
            onDismiss: () => ref.read(updateDownloadProvider.notifier).reset(),
          ),
        );
    }
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String semanticsLabel;
  final Widget child;

  const _Banner({
    required this.color,
    required this.semanticsLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: semanticsLabel,
      container: true,
      child: Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}

class _PreparingContent extends StatelessWidget {
  final String version;
  const _PreparingContent({required this.version});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '准备下载 v$version...',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DownloadingContent extends StatelessWidget {
  final UpdateDownloading state;
  final VoidCallback onCancel;
  const _DownloadingContent({required this.state, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final percent = (state.progress * 100).toStringAsFixed(0);
    final sizeText = _formatBytes(state.bytesDownloaded, state.totalBytes);
    final mirrorLabel = state.mirrorIndex > 0
        ? '（源${state.mirrorIndex + 1}）'
        : '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '下载中 v${state.version} · $percent%$mirrorLabel',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.progress > 0 ? state.progress : null,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              if (sizeText != null) ...[
                const SizedBox(height: 4),
                Text(
                  sizeText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: '取消下载',
          onPressed: onCancel,
        ),
      ],
    );
  }

  String? _formatBytes(int downloaded, int total) {
    if (downloaded < 0 || total <= 0) return null;
    return '${_mb(downloaded)} / ${_mb(total)} MB';
  }

  String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
}

class _CompletedContent extends StatelessWidget {
  final String version;
  final VoidCallback onInstall;
  const _CompletedContent({required this.version, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'v$version 下载完成',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onInstall,
          child: const Text('立即安装'),
        ),
      ],
    );
  }
}

class _FailedContent extends StatelessWidget {
  final UpdateFailed failed;
  final UpdateInfo? retryInfo;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const _FailedContent({
    required this.failed,
    required this.retryInfo,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${failed.error.userMessage}（v${failed.version}）',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        if (onRetry != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: onDismiss,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
