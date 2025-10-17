import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/hot_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';

class ListPage extends ConsumerStatefulWidget {
  final String type;

  const ListPage({super.key, required this.type});

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  late String currentType;
  int currentPage = 1;
  static const int itemsPerPage = 20;
  bool _isRefreshing = false;
  int _refreshTrigger = 0; // 用于触发列表项重新动画
  bool _hasPendingUpdate = false;

  @override
  void initState() {
    super.initState();
    currentType = widget.type;
    _checkPendingUpdate();
  }

  Future<void> _checkPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPending = prefs.getString(AppConstants.keyPendingUpdateVersion) != null;
    if (mounted) {
      setState(() {
        _hasPendingUpdate = hasPending;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotListAsync = ref.watch(
      hotListProvider(HotListParams(type: currentType)),
    );
    final settings = ref.watch(settingsProvider);
    final categories = settings.categories
        .where((c) => c.show)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // 获取当前榜单分类信息
    final currentCategory = categories.firstWhere(
      (c) => c.name == currentType,
      orElse: () => categories.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: hotListAsync.maybeWhen(
          data: (data) => _buildAppBarTitle(data, currentCategory),
          orElse: () => _buildAppBarTitle(null, currentCategory),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : () async {
              setState(() => _isRefreshing = true);

              // 等待淡出动画
              await Future.delayed(const Duration(milliseconds: 150));

              // invalidate 并触发刷新
              ref.invalidate(
                hotListProvider(
                  HotListParams(type: currentType, forceRefresh: false),
                ),
              );

              // 触发强制刷新
              // ignore: unawaited_futures
              ref.read(
                hotListProvider(
                  HotListParams(type: currentType, forceRefresh: true),
                ).future,
              );

              // 增加刷新触发器，触发列表项重新动画
              setState(() => _refreshTrigger++);

              // 等待刷新完成
              await Future.delayed(const Duration(milliseconds: 500));

              if (mounted) {
                setState(() => _isRefreshing = false);
              }
            },
            tooltip: '刷新数据',
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasPendingUpdate,
              child: const Icon(Icons.settings),
            ),
            onPressed: () => context.push('/settings'),
            tooltip: '设置',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildCategoryTabs(categories),
        ),
      ),
      body: hotListAsync.when(
        data: (data) => _buildContent(data),
        loading: () => _buildLoadingSkeleton(),
        error: (error, stack) => _buildError(),
      ),
    );
  }

  Widget _buildAppBarTitle(dynamic data, dynamic category) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo 图标
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            category.icon,
            width: 28,
            height: 28,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 28,
                height: 28,
                color: Colors.grey.shade300,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // 标题和副标题
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data?.title ?? category.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (data?.updateTime != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatUpdateTime(data.updateTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatUpdateTime(String? updateTime) {
    if (updateTime == null) return '';
    try {
      final dateTime = DateTime.parse(updateTime);
      final now = DateTime.now();
      final localTime = dateTime.toLocal();

      if (now.difference(localTime).inMinutes < 60) {
        return '${now.difference(localTime).inMinutes}分钟前';
      } else if (now.difference(localTime).inHours < 24) {
        return '${now.difference(localTime).inHours}小时前';
      } else {
        return '${localTime.month}-${localTime.day} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return updateTime;
    }
  }

  Widget _buildCategoryTabs(List categories) {
    return Container(
      height: 60,
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.name == currentType;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset(
                      category.icon,
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 20,
                          height: 20,
                          color: Colors.grey.shade300,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(category.label),
                ],
              ),
              onSelected: (selected) {
                if (selected && currentType != category.name) {
                  setState(() {
                    currentType = category.name;
                    currentPage = 1;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(dynamic data) {
    final settings = ref.watch(settingsProvider);
    final totalItems = data.data.length;
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, totalItems);
    final pageData = data.data.sublist(startIndex, endIndex);
    final totalPages = (totalItems / itemsPerPage).ceil();

    return Column(
      children: [
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: pageData.length,
            itemBuilder: (context, index) {
              final item = pageData[index];
              final globalIndex = startIndex + index;
              return _AnimatedListItem(
                key: ValueKey(globalIndex),
                index: index,
                isRefreshing: _isRefreshing,
                refreshTrigger: _refreshTrigger,
                child: _buildListItem(item, globalIndex, settings),
              );
            },
          ),
        ),

        // Pagination
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildListItem(dynamic item, int index, dynamic settings) {
    return InkWell(
      onTap: () => _launchUrl(item.url, item: item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 序号徽章
            _buildRankBadge(index),
            const SizedBox(width: 12),

            // 标题和描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: settings.listFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.desc != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.desc,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: settings.listFontSize - 2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (item.hot != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: settings.listFontSize - 2,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.hotText,
                          style: TextStyle(
                            fontSize: settings.listFontSize - 4,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int index) {
    Color? bgColor;
    Color? textColor;

    if (index == 0) {
      bgColor = const Color(0xFFEA444D);
      textColor = Colors.white;
    } else if (index == 1) {
      bgColor = const Color(0xFFED702D);
      textColor = Colors.white;
    } else if (index == 2) {
      bgColor = const Color(0xFFEEAD3F);
      textColor = Colors.white;
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 根据屏幕宽度决定显示的页码数量
    final maxPages = screenWidth < 400 ? 3 : (screenWidth < 600 ? 5 : 7);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => setState(() => currentPage--)
                : null,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(
                totalPages > maxPages ? maxPages : totalPages,
                (index) {
                  int pageNum;
                  final halfMax = maxPages ~/ 2;
                  if (totalPages <= maxPages) {
                    pageNum = index + 1;
                  } else if (currentPage <= halfMax + 1) {
                    pageNum = index + 1;
                  } else if (currentPage >= totalPages - halfMax) {
                    pageNum = totalPages - maxPages + index + 1;
                  } else {
                    pageNum = currentPage - halfMax + index;
                  }

                  return currentPage == pageNum
                      ? CircleAvatar(
                          radius: 18,
                          child: Text('$pageNum'),
                        )
                      : InkWell(
                          onTap: () => setState(() => currentPage = pageNum),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: Text('$pageNum'),
                          ),
                        );
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => setState(() => currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 20),
          // List skeleton
          Expanded(
            child: ListView.separated(
              itemCount: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 云同步图标
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_sync,
                size: 64,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '服务启动中',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '首次访问需要一点时间，请稍候...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () async {
                setState(() => _isRefreshing = true);

                // 等待淡出动画
                await Future.delayed(const Duration(milliseconds: 150));

                // invalidate 并触发刷新
                ref.invalidate(
                  hotListProvider(
                    HotListParams(type: currentType, forceRefresh: false),
                  ),
                );

                // 触发强制刷新
                // ignore: unawaited_futures
                ref.read(
                  hotListProvider(
                    HotListParams(type: currentType, forceRefresh: true),
                  ).future,
                );

                // 增加刷新触发器，触发列表项重新动画
                setState(() => _refreshTrigger++);

                // 等待刷新完成
                await Future.delayed(const Duration(milliseconds: 500));

                if (mounted) {
                  setState(() => _isRefreshing = false);
                }
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('立即重试', style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url, {dynamic item}) async {
    final uri = Uri.parse(url);
    String? videoId; // 用于保存获取到的视频ID

    // 检测抖音热榜链接且在Android平台
    if (Platform.isAndroid &&
        uri.host.contains('douyin.com') &&
        uri.path.startsWith('/hot/') &&
        item != null &&
        item.title != null) {
      try {
        debugPrint('检测到抖音热榜，尝试获取视频ID: ${item.title}');

        // 1. 获取Cookie
        final cookieUrl =
            'https://www.douyin.com/passport/general/login_guiding_strategy/?aid=6383';
        final cookieResponse = await Dio().get(cookieUrl);

        String? csrfToken;
        final setCookie = cookieResponse.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          final pattern = RegExp(r'passport_csrf_token=(.*?);');
          final match = pattern.firstMatch(setCookie.first);
          if (match != null) {
            csrfToken = match.group(1);
          }
        }

        if (csrfToken == null) {
          debugPrint('无法获取Cookie，降级到浏览器');
          throw Exception('Cookie获取失败');
        }

        debugPrint('Cookie获取成功');

        // 2. 调用视频列表API
        final hotword = Uri.encodeComponent(item.title);
        final videoListUrl =
            'https://aweme-hl.snssdk.com/aweme/v1/hot/search/video/list/'
            '?hotword=$hotword&device_platform=webapp&aid=6383';

        final videoResponse = await Dio().get(
          videoListUrl,
          options: Options(
            headers: {
              'Cookie': 'passport_csrf_token=$csrfToken',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ),
        );

        // 3. 提取视频ID
        final awemeList = videoResponse.data?['aweme_list'];
        if (awemeList != null && awemeList.isNotEmpty) {
          videoId = awemeList[0]['aweme_id'].toString();
          debugPrint('获取到视频ID: $videoId');

          // 4. 尝试用抖音scheme打开
          try {
            final intent = AndroidIntent(
              action: 'android.intent.action.VIEW',
              data: 'snssdk1128://aweme/detail/$videoId',
            );

            await intent.launch();
            debugPrint('成功打开抖音APP');
            return;
          } catch (e) {
            debugPrint('启动抖音APP失败: $e，将使用视频ID降级到浏览器');
            // videoId已保存，继续执行降级逻辑
          }
        } else {
          debugPrint('未找到相关视频，降级到浏览器');
        }
      } catch (e) {
        debugPrint('抖音链接处理失败: $e，降级到浏览器');
      }
    }

    // 降级：浏览器打开
    // 如果是抖音链接且获取到了视频ID，使用视频页面链接而非热榜链接
    Uri finalUri = uri;
    if (videoId != null && uri.host.contains('douyin.com')) {
      finalUri = Uri.parse('https://www.douyin.com/video/$videoId');
      debugPrint('使用视频链接降级: $finalUri');
    }

    if (await canLaunchUrl(finalUri)) {
      await launchUrl(finalUri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 带渐入动画的列表项包装器
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final bool isRefreshing;
  final int refreshTrigger;
  final Widget child;

  const _AnimatedListItem({
    super.key,
    required this.index,
    required this.isRefreshing,
    required this.refreshTrigger,
    required this.child,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> {
  bool _isVisible = false;
  int _lastRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastRefreshTrigger = widget.refreshTrigger;
    // 初始加载时的延迟动画，每4个一批，间隔40ms
    final delay = (widget.index ~/ 4) * 40 + 100;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_AnimatedListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测到刷新触发器变化时，重新触发动画
    if (widget.refreshTrigger != _lastRefreshTrigger) {
      _lastRefreshTrigger = widget.refreshTrigger;
      // 刷新完成，逐个显示，每个间隔50ms
      setState(() => _isVisible = false);
      final delay = widget.index * 50 + 100;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          setState(() => _isVisible = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _isVisible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
