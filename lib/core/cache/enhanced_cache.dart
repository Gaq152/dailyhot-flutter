import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_config.dart';

/// 增强型本地缓存
///
/// 特性：
/// - 支持自定义过期时间
/// - 支持离线模式（返回过期缓存）
/// - 自动清理过期数据
class EnhancedCache {
  final Box _cacheBox;
  final CacheConfig config;

  EnhancedCache(this._cacheBox, this.config);

  /// 保存数据到缓存
  Future<void> save(
    String key,
    Map<String, dynamic> data, {
    Duration? customExpiration,
  }) async {
    final expiration = customExpiration ?? config.defaultExpiration;

    await _cacheBox.put(key, {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiration': expiration.inMilliseconds,
    });
  }

  /// 获取缓存数据
  ///
  /// [key] 缓存键
  /// [maxAge] 自定义最大缓存时间
  /// 返回：数据或 null（如果不存在或已过期）
  Map<String, dynamic>? get(String key, {Duration? maxAge}) {
    final cache = _cacheBox.get(key);
    if (cache == null) return null;

    final timestamp = cache['timestamp'] as int;
    final expirationMs = cache['expiration'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = Duration(milliseconds: now - timestamp);
    final maxCacheAge = maxAge ?? Duration(milliseconds: expirationMs);

    // 检查是否过期
    if (age > maxCacheAge) {
      // 如果不启用离线模式，删除过期缓存
      if (!config.enableOfflineMode) {
        _cacheBox.delete(key);
      }
      return null;
    }

    return cache['data'] as Map<String, dynamic>;
  }

  /// 获取过期缓存（用于离线模式）
  ///
  /// 即使数据已过期，只要还在保留期内就返回
  CachedData? getStale(String key) {
    if (!config.enableOfflineMode) {
      return null;
    }

    final cache = _cacheBox.get(key);
    if (cache == null) return null;

    final timestamp = cache['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = Duration(milliseconds: now - timestamp);

    // 检查是否超过最大保留时间
    if (age > config.staleExpiration) {
      _cacheBox.delete(key);
      return null;
    }

    return CachedData(
      data: cache['data'] as Map<String, dynamic>,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      isStale: age > Duration(milliseconds: cache['expiration'] as int),
    );
  }

  /// 检查缓存是否存在且未过期
  bool isValid(String key) {
    return get(key) != null;
  }

  /// 检查缓存年龄
  Duration? getCacheAge(String key) {
    final cache = _cacheBox.get(key);
    if (cache == null) return null;

    final timestamp = cache['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: now - timestamp);
  }

  /// 删除指定缓存
  Future<void> delete(String key) async {
    await _cacheBox.delete(key);
  }

  /// 清除所有缓存
  Future<void> clear() async {
    await _cacheBox.clear();
  }

  /// 清理过期缓存
  Future<int> cleanExpired() async {
    int count = 0;
    final keys = _cacheBox.keys.toList();

    for (final key in keys) {
      final cache = _cacheBox.get(key);
      if (cache == null) continue;

      final timestamp = cache['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = Duration(milliseconds: now - timestamp);

      // 删除超过保留期的缓存
      if (age > config.staleExpiration) {
        await _cacheBox.delete(key);
        count++;
      }
    }

    return count;
  }

  /// 获取缓存统计信息
  CacheStats getStats() {
    int total = 0;
    int valid = 0;
    int stale = 0;
    int expired = 0;

    final keys = _cacheBox.keys.toList();
    total = keys.length;

    for (final key in keys) {
      final cache = _cacheBox.get(key);
      if (cache == null) continue;

      final timestamp = cache['timestamp'] as int;
      final expirationMs = cache['expiration'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = Duration(milliseconds: now - timestamp);

      if (age <= Duration(milliseconds: expirationMs)) {
        valid++;
      } else if (age <= config.staleExpiration) {
        stale++;
      } else {
        expired++;
      }
    }

    return CacheStats(
      total: total,
      valid: valid,
      stale: stale,
      expired: expired,
    );
  }
}

/// 缓存数据包装
class CachedData {
  final Map<String, dynamic> data;
  final DateTime cachedAt;
  final bool isStale;

  CachedData({
    required this.data,
    required this.cachedAt,
    required this.isStale,
  });

  /// 缓存年龄
  Duration get age => DateTime.now().difference(cachedAt);

  /// 格式化年龄显示
  String get ageText {
    if (age.inDays > 0) {
      return '${age.inDays} 天前';
    } else if (age.inHours > 0) {
      return '${age.inHours} 小时前';
    } else if (age.inMinutes > 0) {
      return '${age.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}

/// 缓存统计信息
class CacheStats {
  final int total; // 总缓存数
  final int valid; // 有效缓存
  final int stale; // 过期但可用（离线模式）
  final int expired; // 完全过期

  CacheStats({
    required this.total,
    required this.valid,
    required this.stale,
    required this.expired,
  });

  double get hitRate {
    if (total == 0) return 0.0;
    return valid / total;
  }

  @override
  String toString() {
    return 'CacheStats(total: $total, valid: $valid, stale: $stale, expired: $expired)';
  }
}

/// 缓存初始化
class CacheManager {
  static EnhancedCache? _instance;

  static Future<EnhancedCache> initialize() async {
    if (_instance != null) return _instance!;

    await Hive.initFlutter();
    final box = await Hive.openBox(AppConfig.hiveCacheBoxName);

    _instance = EnhancedCache(box, AppConfig.cacheConfig);

    // 启动时清理过期缓存
    _instance!.cleanExpired();

    return _instance!;
  }

  static EnhancedCache get instance {
    if (_instance == null) {
      throw StateError('CacheManager not initialized. Call initialize() first.');
    }
    return _instance!;
  }
}