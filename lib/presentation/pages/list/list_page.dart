import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/hot_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../data/models/data_result.dart';
import '../../../data/models/hot_list_item.dart';

class ListPage extends ConsumerStatefulWidget {
  final String type;

  const ListPage({super.key, required this.type});

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  late String currentType;
  int _displayedCount = 20;
  bool _isRefreshing = false;
  int _refreshTrigger = 0;
  bool _errorShownForCurrentData = false;
  final ScrollController _tabScrollController = ScrollController();
  final ScrollController _contentScrollController = ScrollController();
  bool _initialScrollDone = false;
  final Map<String, GlobalKey> _tabKeys = {};
  List<dynamic> _cachedCategories = [];

  @override
  void initState() {
    super.initState();
    currentType = widget.type;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedTabInitial();
    });
    _contentScrollController.addListener(_onContentScroll);
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _contentScrollController.dispose();
    ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }

  void _onContentScroll() {
    if (_contentScrollController.position.pixels >=
        _contentScrollController.position.maxScrollExtent - 200) {
      setState(() {
        _displayedCount += 20;
      });
    }
  }

  /// 精确居中滚动：通过 RenderBox 获取 Tab 实际位置，直接计算目标 offset。
  /// 不依赖 ensureVisible（需要目标已在视口内）也不依赖宽度估算。
  void _scrollToSelectedTab({bool animate = true}) {
    if (!_tabScrollController.hasClients) return;
    final key = _tabKeys[currentType];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    final tabBox = ctx.findRenderObject() as RenderBox?;
    if (tabBox == null || !tabBox.attached) return;

    // Tab 中心相对于 ListView 滚动原点的绝对偏移
    final scrollOffset = _tabScrollController.offset;
    final viewportWidth = _tabScrollController.position.viewportDimension;
    final tabLeft = tabBox.localToGlobal(Offset.zero).dx + scrollOffset;
    final tabCenter = tabLeft + tabBox.size.width / 2;
    final targetOffset = (tabCenter - viewportWidth / 2).clamp(
      0.0,
      _tabScrollController.position.maxScrollExtent,
    );

    if (animate) {
      _tabScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _tabScrollController.jumpTo(targetOffset);
    }
    _initialScrollDone = true;
  }

  /// 首次进入：Tab 栏是 ListView.builder 懒加载，目标 Tab 可能未渲染。
  /// 先用真实已渲染 Tab 的平均宽度估算跳转，让目标进入视口，
  /// 再在下一帧用 RenderBox 精确居中。
  void _scrollToSelectedTabInitial() {
    if (_initialScrollDone || _cachedCategories.isEmpty) return;
    if (!_tabScrollController.hasClients) return;

    final index = _cachedCategories.indexWhere((c) => c.name == currentType);
    if (index < 0) return;

    // 用已渲染 Tab 的真实宽度均值估算，比固定 100 更准
    double avgWidth = 100.0;
    final rendered = _tabKeys.values
        .map((k) => k.currentContext?.findRenderObject() as RenderBox?)
        .whereType<RenderBox>()
        .toList();
    if (rendered.isNotEmpty) {
      avgWidth = rendered.map((b) => b.size.width).reduce((a, b) => a + b) /
          rendered.length;
    }

    final viewportWidth = _tabScrollController.position.viewportDimension;
    final rough = (index * (avgWidth + 8)) - viewportWidth / 2 + avgWidth / 2;
    _tabScrollController.jumpTo(
      rough.clamp(0.0, _tabScrollController.position.maxScrollExtent),
    );

    // 目标 Tab 现在应已进入视口，下一帧用 RenderBox 精确居中
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelectedTab(animate: false);
    });
  }

  /// 检查是否为无意义的占位文本
  bool _isPlaceholderDesc(String desc) {
    const placeholders = ['该视频暂无简介', '暂无简介', '-', '无', 'null', '暂无描述', '暂无内容'];
    final trimmed = desc.trim();
    return placeholders.contains(trimmed) || trimmed.length < 2;
  }

  /// 获取当前分类信息
  dynamic _getCurrentCategory() {
    final settings = ref.read(settingsProvider);
    final categories = settings.categories.where((c) => c.show).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return categories.firstWhere(
      (c) => c.name == currentType,
      orElse: () => categories.first,
    );
  }

  /// 显示错误提示 SnackBar（每次数据加载只显示一次）
  void _showErrorSnackBar(DataResult result) {
    // 避免同一份数据重复显示
    if (_errorShownForCurrentData) return;
    _errorShownForCurrentData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getErrorIcon(result.errorType),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(result.userFriendlyMessage)),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// 根据错误类型获取图标
  IconData _getErrorIcon(DataErrorType errorType) {
    switch (errorType) {
      case DataErrorType.networkError:
        return Icons.wifi_off;
      case DataErrorType.serverError:
        return Icons.cloud_off;
      case DataErrorType.parseError:
        return Icons.error_outline;
      case DataErrorType.timeoutError:
        return Icons.access_time;
      default:
        return Icons.warning_amber;
    }
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _errorShownForCurrentData = false; // 重置，允许显示新错误
    });

    try {
      // 先 invalidate provider，确保重新执行网络请求
      // 注意：必须在 read 之前 invalidate，否则会返回缓存结果
      ref.invalidate(
        hotListProvider(HotListParams(type: currentType, forceRefresh: true)),
      );

      // 使用 forceRefresh: true 触发强制刷新（绕过 API 服务的 Redis 缓存）
      final result = await ref.read(
        hotListProvider(
          HotListParams(type: currentType, forceRefresh: true),
        ).future,
      );

      // 刷新后也使 forceRefresh: false 的 provider 失效，以便正常浏览使用新数据
      ref.invalidate(
        hotListProvider(HotListParams(type: currentType, forceRefresh: false)),
      );

      setState(() => _refreshTrigger++);

      // 显示刷新结果提示
      if (mounted) {
        final itemCount = result.data?.data.length ?? 0;
        final isFromCache = result.source != DataSource.network;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.hasError ? Icons.warning_amber : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.hasError
                        ? '刷新失败，显示缓存数据'
                        : isFromCache
                        ? '已加载 $itemCount 条数据（缓存）'
                        : '已刷新 $itemCount 条数据',
                  ),
                ),
              ],
            ),
            backgroundColor: result.hasError
                ? Colors.orange.shade700
                : Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 刷新出错时的提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('刷新失败，请稍后重试'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotListAsync = ref.watch(
      hotListProvider(HotListParams(type: currentType)),
    );
    final settings = ref.watch(settingsProvider);
    final categories = settings.categories.where((c) => c.show).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // 缓存分类列表，供首次滚动使用
    _cachedCategories = categories;

    // 获取当前榜单分类信息
    final currentCategory = categories.firstWhere(
      (c) => c.name == currentType,
      orElse: () => categories.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: hotListAsync.maybeWhen(
          data: (result) => _buildAppBarTitle(result.data, currentCategory),
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
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: '刷新数据',
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: settings.hasPendingUpdate,
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
      body: Column(
        children: [
          if (ref.watch(isOfflineProvider))
            Semantics(
              liveRegion: true,
              label: '当前无网络连接，显示缓存数据',
              container: true,
              child: Container(
                width: double.infinity,
                color: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Text(
                        '当前无网络连接，显示缓存数据',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: hotListAsync.when(
              data: (result) {
                // 处理 DataResult
                if (result.isFailed) {
                  // 完全失败，显示错误页面
                  return _buildError(result.errorType, result.failureMessage);
                }

                // 有数据（可能是网络数据或缓存数据）
                // 如果使用了过期缓存，显示提示
                if (result.isStaleData && result.hasError) {
                  _showErrorSnackBar(result);
                }

                return _buildContent(result.data!);
              },
              loading: () => _buildLoadingSkeleton(),
              error: (error, stack) =>
                  _buildError(DataErrorType.unknownError, '加载失败，请稍后重试'),
            ),
          ),
        ],
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: ListView.builder(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.name == currentType;

          // 为每个 Tab 创建或获取 GlobalKey
          _tabKeys.putIfAbsent(category.name, () => GlobalKey());
          final tabKey = _tabKeys[category.name]!;

          // 首次渲染完成后，如果还没滚动过，尝试滚动到选中项
          if (isSelected && !_initialScrollDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _initialScrollDone) return;
              _scrollToSelectedTab(animate: false);
            });
          }

          return Padding(
            key: tabKey,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              side: BorderSide.none,
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
                  Text(
                    category.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              onSelected: (selected) {
                if (selected && currentType != category.name) {
                  setState(() {
                    currentType = category.name;
                    _displayedCount = 20;
                    _errorShownForCurrentData = false;
                  });

                  // 点击后滚动到中心
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToSelectedTab(animate: true);
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
    final visibleCount = _displayedCount.clamp(0, totalItems);
    final pageData = data.data.sublist(0, visibleCount);
    final hasMore = visibleCount < totalItems;

    return ListView.separated(
      controller: _contentScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: pageData.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, index) => index < pageData.length - 1
          ? Divider(height: 1, thickness: 0.5, indent: 56, color: Theme.of(context).colorScheme.outlineVariant)
          : const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= pageData.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = pageData[index];
        return _AnimatedListItem(
          key: ValueKey(index),
          index: index,
          isRefreshing: _isRefreshing,
          refreshTrigger: _refreshTrigger,
          child: _buildListItem(item, index, settings, _getCurrentCategory()),
        );
      },
    );
  }

  Widget _buildListItem(
    HotListItem item,
    int index,
    dynamic settings,
    dynamic category,
  ) {
    final hotSuffix = item.hot != null ? '，热度${item.hotText}' : '';
    final descSuffix =
        (item.desc != null &&
            item.desc!.isNotEmpty &&
            !_isPlaceholderDesc(item.desc!))
        ? '，${item.desc}'
        : '';
    return Semantics(
      button: true,
      label: '第${index + 1}条，${item.title}$descSuffix$hotSuffix，点击查看详情',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openDetail(item, category),
        onLongPress: () => _shareItem(item),
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
                    if (item.desc != null &&
                        item.desc!.isNotEmpty &&
                        !_isPlaceholderDesc(item.desc!)) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.desc!,
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
                            Icons.local_fire_department_rounded,
                            size: settings.listFontSize - 2,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.hotText,
                            style: TextStyle(
                              fontSize: settings.listFontSize - 4,
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
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

  Widget _buildLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
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
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey,
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
      ),
    );
  }

  Widget _buildError(DataErrorType errorType, String message) {
    // 根据错误类型选择图标和颜色
    IconData icon;
    Color iconColor;
    String title;

    switch (errorType) {
      case DataErrorType.networkError:
        icon = Icons.wifi_off;
        iconColor = Colors.orange.shade400;
        title = '网络连接失败';
      case DataErrorType.serverError:
        icon = Icons.cloud_off;
        iconColor = Colors.red.shade400;
        title = '服务器异常';
      case DataErrorType.parseError:
        icon = Icons.error_outline;
        iconColor = Colors.purple.shade400;
        title = '数据异常';
      case DataErrorType.timeoutError:
        icon = Icons.access_time;
        iconColor = Colors.blue.shade400;
        title = '服务启动中';
      default:
        icon = Icons.cloud_sync;
        iconColor = Colors.blue.shade400;
        title = '加载失败';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: iconColor),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('立即重试', style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
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

  /// 打开详情页
  void _openDetail(HotListItem item, dynamic category) {
    context.push(
      '/detail',
      extra: {
        'item': item,
        'categoryIcon': category.icon,
        'categoryLabel': category.label,
      },
    );
  }

  /// 长按分享列表项
  Future<void> _shareItem(HotListItem item) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '${item.title}\n${item.url}',
      subject: item.title,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
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
      final delay = (widget.index ~/ 4) * 40 + 100;
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
