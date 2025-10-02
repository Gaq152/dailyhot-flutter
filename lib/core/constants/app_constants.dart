class AppConstants {
  // 应用信息
  static const String appName = '每日热点';
  static const String appVersion = '1.0.0';

  // 网络配置
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // 缓存配置
  static const String hiveBoxName = 'dailyhot';
  static const String hiveCacheBoxName = 'cache';

  // 本地存储 Key
  static const String keyThemeMode = 'theme_mode';
  static const String keyCategories = 'categories';
}
