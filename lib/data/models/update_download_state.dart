/// 应用内更新下载状态：涵盖空闲 / 准备 / 下载中 / 完成 / 失败 五态
sealed class UpdateDownloadState {
  const UpdateDownloadState();
}

class UpdateIdle extends UpdateDownloadState {
  const UpdateIdle();
}

class UpdatePreparing extends UpdateDownloadState {
  final String version;
  const UpdatePreparing(this.version);
}

class UpdateDownloading extends UpdateDownloadState {
  final String version;
  final double progress; // 0.0 ~ 1.0
  final int bytesDownloaded;
  final int totalBytes;
  final int mirrorIndex;

  const UpdateDownloading({
    required this.version,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.mirrorIndex,
  });

  UpdateDownloading copyWith({
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    int? mirrorIndex,
  }) {
    return UpdateDownloading(
      version: version,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      mirrorIndex: mirrorIndex ?? this.mirrorIndex,
    );
  }
}

class UpdateCompleted extends UpdateDownloadState {
  final String version;
  final String filePath;
  const UpdateCompleted({required this.version, required this.filePath});
}

class UpdateFailed extends UpdateDownloadState {
  final String version;
  final UpdateDownloadError error;
  final int attemptedMirrors;
  final String? detail;

  const UpdateFailed({
    required this.version,
    required this.error,
    required this.attemptedMirrors,
    this.detail,
  });
}

enum UpdateDownloadError { network, diskFull, cancelled, unknown }

extension UpdateDownloadErrorX on UpdateDownloadError {
  String get userMessage {
    switch (this) {
      case UpdateDownloadError.network:
        return '网络下载失败';
      case UpdateDownloadError.diskFull:
        return '存储空间不足';
      case UpdateDownloadError.cancelled:
        return '下载已取消';
      case UpdateDownloadError.unknown:
        return '下载失败';
    }
  }
}
