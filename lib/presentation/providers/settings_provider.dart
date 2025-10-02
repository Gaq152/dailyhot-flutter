import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/hot_list_category.dart';
import '../../core/constants/hot_list_data.dart';

/// 设置状态类
class SettingsState {
  final ThemeMode themeMode;
  final bool themeAuto;
  final double listFontSize;
  final List<HotListCategory> categories;
  final bool autoCheckUpdate;

  SettingsState({
    required this.themeMode,
    required this.themeAuto,
    required this.listFontSize,
    required this.categories,
    required this.autoCheckUpdate,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? themeAuto,
    double? listFontSize,
    List<HotListCategory>? categories,
    bool? autoCheckUpdate,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      themeAuto: themeAuto ?? this.themeAuto,
      listFontSize: listFontSize ?? this.listFontSize,
      categories: categories ?? this.categories,
      autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
    );
  }
}

/// 设置管理器
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          themeMode: ThemeMode.system,
          themeAuto: true,
          listFontSize: 16.0,
          categories: HotListData.defaultCategories,
          autoCheckUpdate: true,
        )) {
    _loadSettings();
  }

  /// 从本地存储加载设置
  Future<void> _loadSettings() async {
    final themeModeIndex = _prefs.getInt('themeMode') ?? 0;
    final themeAuto = _prefs.getBool('themeAuto') ?? true;
    final listFontSize = _prefs.getDouble('listFontSize') ?? 16.0;
    final autoCheckUpdate = _prefs.getBool('auto_check_update') ?? true;

    // 加载分类列表
    final categoriesJson = _prefs.getStringList('categories');
    List<HotListCategory> categories;
    if (categoriesJson != null && categoriesJson.isNotEmpty) {
      // 从保存的数据创建Map，便于查找
      final savedMap = <String, Map<String, dynamic>>{};
      for (var json in categoriesJson) {
        final parts = json.split('|');
        savedMap[parts[0]] = {
          'order': int.parse(parts[1]),
          'show': parts[2] == 'true',
        };
      }

      // 合并默认列表和已保存设置
      categories = [];
      for (var defaultCategory in HotListData.defaultCategories) {
        if (savedMap.containsKey(defaultCategory.name)) {
          // 已保存的接口：使用保存的order和show
          final saved = savedMap[defaultCategory.name]!;
          categories.add(defaultCategory.copyWith(
            order: saved['order'] as int,
            show: saved['show'] as bool,
          ));
        } else {
          // 新增的接口：使用默认值
          categories.add(defaultCategory);
        }
      }

      // 按order排序
      categories.sort((a, b) => a.order.compareTo(b.order));
    } else {
      categories = HotListData.defaultCategories;
    }

    state = SettingsState(
      themeMode: ThemeMode.values[themeModeIndex],
      themeAuto: themeAuto,
      listFontSize: listFontSize,
      categories: categories,
      autoCheckUpdate: autoCheckUpdate,
    );
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt('themeMode', mode.index);
    state = state.copyWith(themeMode: mode, themeAuto: false);
    await _prefs.setBool('themeAuto', false);
  }

  /// 设置主题自动跟随系统
  Future<void> setThemeAuto(bool auto) async {
    await _prefs.setBool('themeAuto', auto);
    state = state.copyWith(themeAuto: auto);

    if (auto) {
      // 如果开启自动，将主题设置为系统
      await _prefs.setInt('themeMode', ThemeMode.system.index);
      state = state.copyWith(themeMode: ThemeMode.system);
    }
  }

  /// 设置列表字体大小
  Future<void> setListFontSize(double size) async {
    await _prefs.setDouble('listFontSize', size);
    state = state.copyWith(listFontSize: size);
  }

  /// 更新分类列表
  Future<void> updateCategories(List<HotListCategory> categories) async {
    // 保存到本地存储
    final categoriesJson = categories.map((c) {
      return '${c.name}|${c.order}|${c.show}';
    }).toList();
    await _prefs.setStringList('categories', categoriesJson);

    state = state.copyWith(categories: categories);
  }

  /// 切换分类显示状态
  Future<void> toggleCategory(String name) async {
    final updatedCategories = state.categories.map((c) {
      if (c.name == name) {
        return c.copyWith(show: !c.show);
      }
      return c;
    }).toList();

    await updateCategories(updatedCategories);
  }

  /// 恢复默认分类顺序
  Future<void> restoreDefaultCategories() async {
    await updateCategories(HotListData.defaultCategories);
  }

  /// 设置自动检查更新
  Future<void> setAutoCheckUpdate(bool value) async {
    await _prefs.setBool('auto_check_update', value);
    state = state.copyWith(autoCheckUpdate: value);
  }

  /// 重置所有设置
  Future<void> resetAll() async {
    await _prefs.clear();
    state = SettingsState(
      themeMode: ThemeMode.system,
      themeAuto: true,
      listFontSize: 16.0,
      categories: HotListData.defaultCategories,
      autoCheckUpdate: true,
    );
  }
}

/// 设置 Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('settingsProvider must be overridden');
});
