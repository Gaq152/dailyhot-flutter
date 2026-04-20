import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 封装 background_downloader + install_plugin，提供应用内更新的底层能力
class UpdateDownloadService {
  static const String _taskGroup = 'dailyhot-update';
  static const String _taskIdPrefix = 'dailyhot-update-v';

  /// 全局一次性初始化：配置通知文案 + 启动本地任务数据库
  /// 应在 runApp 前调用
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final downloader = FileDownloader();
    await downloader.ready;

    downloader.configureNotification(
      running: const TaskNotification(
        '下载更新 {filename}',
        '{progress} · {networkSpeed}',
      ),
      complete: const TaskNotification('下载完成', '点击通知栏横幅进入应用安装新版本'),
      error: const TaskNotification('下载失败', '请在应用内重试'),
      progressBar: true,
    );

    // 重启数据库，恢复被系统杀掉的任务
    await downloader.trackTasks();
    await downloader.start();
  }

  /// APK 下载目录（应用专属外部存储），例如 `/Android/data/{pkg}/files/update`
  Future<Directory> _apkDir() async {
    final external = await getExternalStorageDirectory();
    final root = external ?? await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/update');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 指定版本的 APK 目标绝对路径
  Future<String> resolveApkPath(String version) async {
    final dir = await _apkDir();
    return '${dir.path}/dailyhot-v$version.apk';
  }

  /// 清理 update 目录下除 [keepVersion] 外所有 dailyhot-v*.apk
  Future<void> cleanupOldApks({String? keepVersion}) async {
    try {
      final dir = await _apkDir();
      final keepName = keepVersion != null
          ? 'dailyhot-v$keepVersion.apk'
          : null;
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('dailyhot-v') || !name.endsWith('.apk')) continue;
        if (keepName != null && name == keepName) continue;
        try {
          entity.deleteSync();
        } catch (e) {
          debugPrint('清理旧 APK 失败: $name, $e');
        }
      }
    } catch (e) {
      debugPrint('cleanupOldApks 异常: $e');
    }
  }

  /// 指定版本的 APK 是否已下载完整（文件存在且 size > 0）
  Future<bool> isApkAlreadyDownloaded(String version) async {
    final path = await resolveApkPath(version);
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      return file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  /// 构造指定镜像的下载任务
  Future<DownloadTask> buildTask({
    required String version,
    required String url,
    required int mirrorIndex,
  }) async {
    final dir = await _apkDir();
    return DownloadTask(
      taskId: '$_taskIdPrefix$version-m$mirrorIndex',
      url: url,
      filename: 'dailyhot-v$version.apk',
      baseDirectory: BaseDirectory.root,
      directory: dir.path,
      group: _taskGroup,
      updates: Updates.statusAndProgress,
      retries: 0, // 镜像级重试由 Notifier 控制，任务级不再自动重试
      allowPause: false,
      displayName: 'DailyHot v$version',
    );
  }

  /// 运行一个下载任务并等待结束，进度通过 [onProgress] 回调
  Future<TaskStatusUpdate> runTask(
    DownloadTask task, {
    required void Function(double progress, int bytes, int total) onProgress,
  }) {
    return FileDownloader().download(
      task,
      onProgress: (progress) {
        // progress 范围 0~1；task 的 expectedFileSize 在进度更新中未直接暴露
        // 这里拿不到具体字节数时传 -1，由上层处理显示
        onProgress(progress.clamp(0.0, 1.0), -1, -1);
      },
    );
  }

  /// 取消某版本所有进行中任务
  Future<void> cancelByVersion(String version) async {
    final prefix = '$_taskIdPrefix$version';
    try {
      final tasks = await FileDownloader().allTasks(group: _taskGroup);
      final ids = tasks
          .map((t) => t.taskId)
          .where((id) => id.startsWith(prefix))
          .toList();
      if (ids.isNotEmpty) {
        await FileDownloader().cancelTasksWithIds(ids);
      }
    } catch (e) {
      debugPrint('cancelByVersion 异常: $e');
    }
  }

  /// 取消全部下载任务
  Future<void> cancelAll() async {
    try {
      final tasks = await FileDownloader().allTasks(group: _taskGroup);
      final ids = tasks.map((t) => t.taskId).toList();
      if (ids.isNotEmpty) {
        await FileDownloader().cancelTasksWithIds(ids);
      }
    } catch (e) {
      debugPrint('cancelAll 异常: $e');
    }
  }

  /// 调起系统安装器
  Future<bool> installApk(String filePath) async {
    try {
      await InstallPlugin.installApk(filePath);
      return true;
    } catch (e) {
      debugPrint('installApk 失败: $e');
      return false;
    }
  }

  /// 申请 REQUEST_INSTALL_PACKAGES 权限，若未授予会被 install_plugin 自动跳到系统设置
  Future<bool> ensureInstallPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  /// Android 13+ 申请 POST_NOTIFICATIONS 权限，拒绝也允许继续下载
  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
