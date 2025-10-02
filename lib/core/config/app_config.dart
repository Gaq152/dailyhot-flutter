/// 应用配置
///
/// 使用腾讯云CloudBase部署的API服务
class AppConfig {
  /// API 基础地址（腾讯云CloudBase云托管）
  static const String apiBaseUrl =
      'https://daliyhot-vercel-190574-4-1324174178.sh.run.tcloudbase.com';

  /// 应用信息
  static const String appName = '每日热点';
  static const String appVersion = '1.1.0';
  static const String appDescription = '每日热点聚合';

  /// 网络配置
  static const Duration connectTimeout = Duration(seconds: 12);
  /// 接收超时时间设置为40秒，适应serverless后端的冷启动时间
  static const Duration receiveTimeout = Duration(seconds: 40);

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