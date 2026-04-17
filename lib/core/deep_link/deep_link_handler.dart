import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../router/app_router.dart';

/// 处理 dailyhot:// 系列 Deep Link
///
/// 支持格式：`dailyhot://app/list/{type}`
/// 其中 type 对应平台名，例如 bilibili、weibo、zhihu 等
class DeepLinkHandler {
  DeepLinkHandler._();

  static final DeepLinkHandler instance = DeepLinkHandler._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialLinkHandled = false;

  Future<void> init() async {
    // 处理冷启动唤起
    if (!_initialLinkHandled) {
      _initialLinkHandled = true;
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          _handle(initialUri);
        }
      } catch (e) {
        debugPrint('DeepLink 获取冷启动链接失败: $e');
      }
    }

    // 运行期热启动唤起
    _subscription ??= _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object err) => debugPrint('DeepLink 流错误: $err'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handle(Uri uri) {
    // 仅处理自定义 scheme 的 dailyhot://app/...
    if (uri.scheme != 'dailyhot') return;

    // 取 path 部分作为应用内路由，例如 /list/bilibili
    final target = uri.path.isEmpty ? '/' : uri.path;

    // 延迟到下一个事件循环，确保 GoRouter 已初始化
    scheduleMicrotask(() {
      try {
        appRouter.go(target);
      } catch (e) {
        debugPrint('DeepLink 跳转失败 target=$target: $e');
      }
    });
  }
}
