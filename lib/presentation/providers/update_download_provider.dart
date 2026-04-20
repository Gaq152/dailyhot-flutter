import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/update_download_state.dart';
import '../../data/services/update_download_service.dart';
import '../../data/services/update_service.dart';
import 'dependency_providers.dart';

/// 应用内更新下载状态管理器
class UpdateDownloadNotifier extends StateNotifier<UpdateDownloadState> {
  final UpdateDownloadService _service;

  UpdateDownloadNotifier(this._service) : super(const UpdateIdle());

  /// 下载入口（幂等）
  ///
  /// - 当前已在下载同版本 → 忽略
  /// - 当前在下载其它版本 → 先取消再下载新版本
  /// - 目标版本 APK 已下载完整 → 直接进入 Completed
  Future<void> download(UpdateInfo info) async {
    final current = state;

    if (current is UpdateDownloading && current.version == info.version) {
      return;
    }
    if (current is UpdateDownloading && current.version != info.version) {
      await _service.cancelByVersion(current.version);
    }

    if (await _service.isApkAlreadyDownloaded(info.version)) {
      final path = await _service.resolveApkPath(info.version);
      state = UpdateCompleted(version: info.version, filePath: path);
      return;
    }

    state = UpdatePreparing(info.version);

    // 通知权限拒绝不阻断下载，仅影响通知栏展示
    await _service.ensureNotificationPermission();

    await _service.cleanupOldApks(keepVersion: info.version);

    final mirrors = info.mirrorUrls.isNotEmpty
        ? info.mirrorUrls
        : [info.downloadUrl];

    await _tryMirror(info, mirrors, 0);
  }

  Future<void> _tryMirror(
    UpdateInfo info,
    List<String> mirrors,
    int index,
  ) async {
    if (index >= mirrors.length) {
      state = UpdateFailed(
        version: info.version,
        error: UpdateDownloadError.network,
        attemptedMirrors: mirrors.length,
        detail: '所有下载源均失败',
      );
      return;
    }

    state = UpdateDownloading(
      version: info.version,
      progress: 0,
      bytesDownloaded: -1,
      totalBytes: -1,
      mirrorIndex: index,
    );

    DownloadTask task;
    try {
      task = await _service.buildTask(
        version: info.version,
        url: mirrors[index],
        mirrorIndex: index,
      );
    } catch (e) {
      debugPrint('buildTask 失败: $e');
      await _tryMirror(info, mirrors, index + 1);
      return;
    }

    TaskStatusUpdate result;
    try {
      result = await _service.runTask(
        task,
        onProgress: (progress, bytes, total) {
          final s = state;
          if (s is UpdateDownloading && s.version == info.version) {
            state = s.copyWith(
              progress: progress,
              bytesDownloaded: bytes,
              totalBytes: total,
              mirrorIndex: index,
            );
          }
        },
      );
    } catch (e) {
      debugPrint('镜像 $index 下载异常: $e');
      await _tryMirror(info, mirrors, index + 1);
      return;
    }

    switch (result.status) {
      case TaskStatus.complete:
        final path = await _service.resolveApkPath(info.version);
        if (!File(path).existsSync()) {
          // 极端情况下 status 为 complete 但文件不存在，降级重试
          await _tryMirror(info, mirrors, index + 1);
          return;
        }
        state = UpdateCompleted(version: info.version, filePath: path);
        return;

      case TaskStatus.canceled:
        // 用户主动取消或版本切换时的取消：不再重试，也不覆盖已迁移的新状态
        final s = state;
        if (s is UpdateDownloading && s.version == info.version) {
          state = UpdateFailed(
            version: info.version,
            error: UpdateDownloadError.cancelled,
            attemptedMirrors: index + 1,
          );
        }
        return;

      case TaskStatus.failed:
      case TaskStatus.notFound:
        final error = _mapException(result.exception);
        if (error == UpdateDownloadError.diskFull) {
          // 磁盘满再试其他镜像也没用
          state = UpdateFailed(
            version: info.version,
            error: error,
            attemptedMirrors: index + 1,
            detail: result.exception?.description,
          );
          return;
        }
        await _tryMirror(info, mirrors, index + 1);
        return;

      default:
        // enqueued / running / waitingToRetry / paused 理论上不会作为 final 返回
        await _tryMirror(info, mirrors, index + 1);
        return;
    }
  }

  UpdateDownloadError _mapException(TaskException? e) {
    if (e == null) return UpdateDownloadError.unknown;
    final type = e.exceptionType;
    final desc = e.description.toLowerCase();
    if (type == 'TaskFileSystemException' ||
        desc.contains('space') ||
        desc.contains('enospc') ||
        desc.contains('disk')) {
      return UpdateDownloadError.diskFull;
    }
    if (type == 'TaskConnectionException' ||
        type == 'TaskHttpException' ||
        type == 'TaskUrlException') {
      return UpdateDownloadError.network;
    }
    return UpdateDownloadError.unknown;
  }

  /// 安装已下载的 APK（仅在 Completed 状态可用）
  Future<bool> install() async {
    final s = state;
    if (s is! UpdateCompleted) return false;

    final granted = await _service.ensureInstallPermission();
    if (!granted) return false;

    return _service.installApk(s.filePath);
  }

  /// 重新从镜像 0 开始下载
  Future<void> retry(UpdateInfo info) async {
    await _service.cancelByVersion(info.version);
    state = const UpdateIdle();
    await download(info);
  }

  /// 取消当前下载并回到 Idle
  Future<void> cancel() async {
    final s = state;
    if (s is UpdateDownloading) {
      await _service.cancelByVersion(s.version);
    } else if (s is UpdatePreparing) {
      await _service.cancelByVersion(s.version);
    }
    state = const UpdateIdle();
  }

  /// 清空状态（例如用户关闭完成/失败横幅）
  void reset() {
    state = const UpdateIdle();
  }
}

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>((ref) {
      return UpdateDownloadNotifier(ref.watch(updateDownloadServiceProvider));
    });
