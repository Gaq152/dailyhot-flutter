import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/config/app_config.dart';

class LocalStorage {
  late Box _settingsBox;
  late Box _cacheBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(AppConfig.hiveBoxName);
    _cacheBox = await Hive.openBox(AppConfig.hiveCacheBoxName);
  }

  /// 保存热榜数据缓存
  Future<void> saveHotListCache(String type, Map<String, dynamic> data) async {
    await _cacheBox.put('hotlist_$type', {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取热榜数据缓存
  Map<String, dynamic>? getHotListCache(String type) {
    final cache = _cacheBox.get('hotlist_$type');
    if (cache == null) return null;

    try {
      // 检查缓存是否过期（1小时）
      final timestamp = cache['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > 3600000) {
        // 异步删除过期缓存，不阻塞主线程
        Future.microtask(() => _cacheBox.delete('hotlist_$type'));
        return null;
      }

      // 转换 Map<dynamic, dynamic> 为 Map<String, dynamic>
      final data = cache['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data.map((key, value) {
          if (value is Map) {
            return MapEntry(key.toString(), Map<String, dynamic>.from(value));
          } else if (value is List) {
            return MapEntry(key.toString(), _convertList(value));
          }
          return MapEntry(key.toString(), value);
        }));
      }
      return null;
    } catch (e) {
      // 缓存数据格式错误，异步删除缓存
      Future.microtask(() => _cacheBox.delete('hotlist_$type'));
      return null;
    }
  }

  /// 递归转换List中的Map
  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return Map<String, dynamic>.from(item.map((key, value) {
          if (value is Map) {
            return MapEntry(key.toString(), Map<String, dynamic>.from(value));
          } else if (value is List) {
            return MapEntry(key.toString(), _convertList(value));
          }
          return MapEntry(key.toString(), value);
        }));
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  /// 保存主题模式
  Future<void> saveThemeMode(String mode) async {
    await _settingsBox.put('theme_mode', mode);
  }

  /// 获取主题模式
  String? getThemeMode() {
    return _settingsBox.get('theme_mode');
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheBox.clear();
  }
}