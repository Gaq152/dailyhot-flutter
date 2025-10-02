import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String changelog;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // 从 assets 中找到 .apk 文件
    final assets = json['assets'] as List;
    final apkAsset = assets.firstWhere(
      (asset) => (asset['name'] as String).endsWith('.apk'),
      orElse: () => {'browser_download_url': ''},
    );

    // 从 Release body 中提取纯粹的更新内容
    final rawBody = json['body'] ?? '';
    final changelog = _extractChangelog(rawBody);

    return UpdateInfo(
      version: (json['tag_name'] as String).replaceFirst('v', ''),
      downloadUrl: apkAsset['browser_download_url'] ?? '',
      changelog: changelog,
      publishedAt: DateTime.parse(json['published_at']),
    );
  }

  /// 从 Release body 中提取 CHANGELOG 部分
  static String _extractChangelog(String body) {
    if (body.isEmpty) return '暂无更新说明';

    // 查找第一个 "---" 之前的内容（排除标题行）
    final lines = body.split('\n');
    final changelogLines = <String>[];
    bool foundTitle = false;
    bool foundSeparator = false;

    for (final line in lines) {
      // 跳过标题行（## 📱 DailyHot v1.0.0）
      if (line.startsWith('## 📱') || line.startsWith('## DailyHot')) {
        foundTitle = true;
        continue;
      }

      // 遇到分隔符就停止
      if (line.trim() == '---') {
        foundSeparator = true;
        break;
      }

      // 收集更新内容
      if (foundTitle) {
        changelogLines.add(line);
      }
    }

    if (changelogLines.isEmpty || !foundSeparator) {
      // 如果没有找到标准格式，返回原始内容的前 500 字符
      return body.length > 500 ? '${body.substring(0, 500)}...' : body;
    }

    // 清理空行和返回内容
    final changelog = changelogLines
        .join('\n')
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n'); // 最多保留两个连续换行

    return changelog.isNotEmpty ? changelog : '暂无更新说明';
  }
}

class UpdateService {
  final Dio _dio = Dio();

  // GitHub 仓库信息
  static const String owner = 'Gaq152';
  static const String repo = 'DailyHotApi';

  /// 检查是否有新版本
  Future<UpdateInfo?> checkUpdate() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 从 GitHub API 获取最新 Release
      final response = await _dio.get(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );

      if (response.statusCode == 200) {
        final updateInfo = UpdateInfo.fromJson(response.data);

        // 比较版本号
        if (_isNewerVersion(currentVersion, updateInfo.version)) {
          return updateInfo;
        }
      }

      return null;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      return null;
    }
  }

  /// 比较版本号（简单实现）
  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }
}
