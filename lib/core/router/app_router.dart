import 'package:go_router/go_router.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/list/list_page.dart';
import '../../presentation/pages/detail/detail_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/webview/webview_page.dart';
import '../../data/models/hot_list_item.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/list/:type',
      builder: (context, state) {
        final type = state.pathParameters['type']!;
        return ListPage(type: type);
      },
    ),
    GoRoute(
      path: '/detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final item = extra['item'] as HotListItem;
        final categoryIcon = extra['categoryIcon'] as String?;
        final categoryLabel = extra['categoryLabel'] as String?;
        return DetailPage(
          item: item,
          categoryIcon: categoryIcon,
          categoryLabel: categoryLabel,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/webview',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final url = extra['url'] as String;
        final title = extra['title'] as String? ?? '加载中...';
        return WebViewPage(url: url, title: title);
      },
    ),
  ],
);
