import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/local/local_storage.dart';
import 'presentation/providers/dependency_providers.dart';
import 'presentation/providers/settings_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  final localStorage = LocalStorage();
  await localStorage.init();

  // 初始化 SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // 注入已初始化的 LocalStorage 实例
        localStorageProvider.overrideWithValue(localStorage),
        // 注入 Settings Provider
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(sharedPrefs),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
