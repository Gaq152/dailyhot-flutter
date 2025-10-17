import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final List<String> mirrorUrls;  // 多个下载源（降级策略）
  final String changelog;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.mirrorUrls = const [],
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

    final originalUrl = apkAsset['browser_download_url'] ?? '';

    // 构建多级下载源（优先级从高到低）
    final mirrors = _buildMirrorUrls(originalUrl);

    // 从 Release body 中提取纯粹的更新内容
    final rawBody = json['body'] ?? '';
    final changelog = _extractChangelog(rawBody);

    return UpdateInfo(
      version: (json['tag_name'] as String).replaceFirst('v', ''),
      downloadUrl: mirrors.isNotEmpty ? mirrors.first : originalUrl,  // 默认使用第一个镜像
      mirrorUrls: mirrors,  // 保存所有镜像供降级使用
      changelog: changelog,
      publishedAt: DateTime.parse(json['published_at']),
    );
  }

  /// 构建多级下载源（三级降级策略）
  static List<String> _buildMirrorUrls(String originalUrl) {
    if (originalUrl.isEmpty) return [];

    return [
      // 第一优先级：ghfast.top 镜像
      originalUrl.replaceFirst(
        'https://github.com',
        'https://ghfast.top/https://github.com',
      ),
      // 第二优先级：自建 Cloudflare Workers
      'https://dailyhot-proxy.anlife123456.workers.dev/$originalUrl',
      // 第三优先级：GitHub 原始地址
      originalUrl,
    ];
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
  late final Dio _dio;

  // GitHub 仓库信息
  static const String owner = 'Gaq152';
  static const String repo = 'dailyhot-flutter';

  UpdateService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // 配置 HTTP 客户端适配器
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();

      // 禁用证书验证（调试模式）
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) => true;
      }

      return client;
    };
  }

  /// 检查是否有新版本
  Future<UpdateInfo?> checkUpdate() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 从 GitHub API 获取最新 Release
      final url = 'https://api.github.com/repos/$owner/$repo/releases/latest';
      debugPrint('检查更新: $url');

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final updateInfo = UpdateInfo.fromJson(response.data);

        // 比较版本号
        if (_isNewerVersion(currentVersion, updateInfo.version)) {
          debugPrint('发现新版本: ${updateInfo.version} (当前: $currentVersion)');
          return updateInfo;
        }

        debugPrint('已是最新版本: $currentVersion');
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
