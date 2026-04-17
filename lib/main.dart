import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/deep_link/deep_link_handler.dart';
import 'data/datasources/local/local_storage.dart';
import 'presentation/providers/dependency_providers.dart';
import 'presentation/providers/settings_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境变量
  await dotenv.load(fileName: '.env');

  // 初始化本地存储
  final localStorage = LocalStorage();
  await localStorage.init();

  // 初始化 SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();

  // 初始化 Deep Link 监听（dailyhot://app/list/{type}）
  // 不 await 冷启动路径，避免阻塞首屏；handler 内部会延迟到路由就绪后再跳转
  // ignore: unawaited_futures
  DeepLinkHandler.instance.init();

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
