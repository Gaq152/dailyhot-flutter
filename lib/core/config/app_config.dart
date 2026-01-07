import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 应用配置
///
/// 使用腾讯云CloudBase部署的API服务
class AppConfig {
  /// API 基础地址（从环境变量读取）
  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        '未配置 API_BASE_URL 环境变量！\n'
        '请确保项目根目录存在 .env 文件，并配置 API_BASE_URL。\n'
        '参考 .env.example 文件进行配置。',
      );
    }
    return url;
  }

  /// 应用信息
  static const String appName = '每日热点';
  static const String appVersion = '1.3.9';
  static const String appDescription = '每日热点聚合';

  /// 网络配置（Deno Deploy 无冷启动，可以使用较短超时）
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// 缓存配置
  static const CacheConfig cacheConfig = CacheConfig(
    defaultExpiration: Duration(hours: 1),
    staleExpiration: Duration(days: 3),
    enableOfflineMode: true,
  );

  /// 本地存储配置
  static const String hiveBoxName = 'dailyhot';
  static const String hiveCacheBoxName = 'cache';
}

/// 缓存配置
class CacheConfig {
  /// 默认缓存过期时间
  final Duration defaultExpiration;

  /// 过期缓存保留时间（用于离线模式）
  final Duration staleExpiration;

  /// 是否启用离线模式
  final bool enableOfflineMode;

  const CacheConfig({
    required this.defaultExpiration,
    required this.staleExpiration,
    required this.enableOfflineMode,
  });
}