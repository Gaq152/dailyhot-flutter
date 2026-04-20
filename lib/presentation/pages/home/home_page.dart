import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hot_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/update_download_provider.dart';
import '../../../data/models/update_download_state.dart';
import '../../../data/services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/update_download_banner.dart';
import 'widgets/hot_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  bool _isRefreshing = false;
  Timer? _updateCheckTimer;
  DateTime _lastActiveTime = DateTime.now();
  UpdateInfo? _lastUpdateInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 延迟执行自动检查更新，避免影响首屏渲染
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _autoCheckUpdate();
      }
    });

    // 设置定期检查（6小时）
    _updateCheckTimer = Timer.periodic(const Duration(hours: 6), (_) {
      if (mounted) {
        _autoCheckUpdate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastActiveTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final elapsed = DateTime.now().difference(_lastActiveTime);
      if (elapsed.inHours >= 1) {
        final settings = ref.read(settingsProvider);
        final categories = settings.categories.where((c) => c.show);
        for (final category in categories) {
          ref.invalidate(hotListProvider(HotListParams(type: category.name)));
        }
      }
    }
  }

  /// 自动检查更新
  Future<void> _autoCheckUpdate() async {
    try {
      // 检查是否启用自动检查更新
      final settings = ref.read(settingsProvider);
      if (!settings.autoCheckUpdate) {
        return;
      }

      // 执行检查更新
      final updateService = UpdateService();
      final updateInfo = await updateService.checkUpdate();

      // 如果有新版本，显示更新对话框
      if (updateInfo != null && mounted) {
        _lastUpdateInfo = updateInfo;
        showUpdateDialog(context, ref, updateInfo);
      }
    } catch (e) {
      // 静默失败，不打扰用户
    }
  }

  /// 刷新所有榜单数据
  Future<void> _refreshAllData() async {
    setState(() => _isRefreshing = true);

    try {
      // 获取所有显示的榜单
      final settings = ref.read(settingsProvider);
      final categories = settings.categories.where((c) => c.show).toList();

      int successCount = 0;
      int failCount = 0;
      int totalItems = 0;

      // 先 invalidate 所有 forceRefresh: true 的 provider，确保重新执行网络请求
      for (final category in categories) {
        ref.invalidate(
          hotListProvider(
            HotListParams(type: category.name, forceRefresh: true),
          ),
        );
      }

      // 并行刷新所有榜单（使用 forceRefresh: true 绕过 API 服务的 Redis 缓存）
      final futures = categories.map((category) {
        return ref.read(
          hotListProvider(
            HotListParams(type: category.name, forceRefresh: true),
          ).future,
        );
      }).toList();

      final results = await Future.wait(futures, eagerError: false);

      // 统计结果
      for (final result in results) {
        if (result.hasError) {
          failCount++;
        } else {
          successCount++;
          totalItems += result.data?.data.length ?? 0;
        }
      }

      // 刷新后使缓存的 provider 失效
      for (final category in categories) {
        ref.invalidate(
          hotListProvider(
            HotListParams(type: category.name, forceRefresh: false),
          ),
        );
      }

      // 显示刷新结果提示
      if (mounted) {
        String message;
        Color backgroundColor;
        IconData icon;

        if (failCount == 0) {
          message = '已刷新 $successCount 个榜单，共 $totalItems 条数据';
          backgroundColor = Colors.green.shade600;
          icon = Icons.check_circle;
        } else if (successCount == 0) {
          message = '刷新失败，请检查网络连接';
          backgroundColor = Colors.red.shade600;
          icon = Icons.error_outline;
        } else {
          message = '已刷新 $successCount 个榜单，$failCount 个失败';
          backgroundColor = Colors.orange.shade600;
          icon = Icons.warning_amber;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor,
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
      // 整体出错时的提示
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
    final settings = ref.watch(settingsProvider);
    final categories = settings.categories.where((c) => c.show).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // 下载完成时弹出确认安装提示
    ref.listen<UpdateDownloadState>(updateDownloadProvider, (prev, next) {
      if (prev is! UpdateCompleted && next is UpdateCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('v${next.version} 下载完成'),
            action: SnackBarAction(
              label: '立即安装',
              onPressed: () =>
                  ref.read(updateDownloadProvider.notifier).install(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
            tooltip: '搜索',
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: '刷新所有榜单',
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
          UpdateDownloadBanner(retryInfo: _lastUpdateInfo),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 响应式列数
                int columns;
                double aspectRatio;
                double spacing;

                if (constraints.maxWidth >= 1500) {
                  columns = 5;
                  aspectRatio = 0.9;
                  spacing = 24;
                } else if (constraints.maxWidth >= 1100) {
                  columns = 4;
                  aspectRatio = 0.9;
                  spacing = 24;
                } else if (constraints.maxWidth >= 800) {
                  columns = 3;
                  aspectRatio = 0.9;
                  spacing = 24;
                } else {
                  // 移动端默认2列，紧凑布局
                  columns = 2;
                  aspectRatio = 0.75;
                  spacing = 12;
                }

                return GridView.builder(
                  padding: EdgeInsets.all(spacing),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _AnimatedCard(
                      index: index,
                      isRefreshing: _isRefreshing,
                      child: Semantics(
                        button: true,
                        label: '${category.label}榜单，点击查看完整列表',
                        child: HotCard(
                          category: category,
                          index: index,
                          externalRefreshing: _isRefreshing,
                          onTap: () => context.push('/list/${category.name}'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 应用图标
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 32,
            height: 32,
            cacheWidth: (32 * MediaQuery.of(context).devicePixelRatio).toInt(),
            cacheHeight: (32 * MediaQuery.of(context).devicePixelRatio).toInt(),
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF3838)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '今日热榜',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const _ClockText(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockText extends StatelessWidget {
  const _ClockText();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data!;
        final weekday = [
          '周日',
          '周一',
          '周二',
          '周三',
          '周四',
          '周五',
          '周六',
        ][now.weekday % 7];
        return Text(
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $weekday',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// 带进入动画的卡片包装器
class _AnimatedCard extends StatefulWidget {
  final int index;
  final bool isRefreshing;
  final Widget child;

  const _AnimatedCard({
    required this.index,
    required this.isRefreshing,
    required this.child,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // 分批延迟显示动画，每批8个，间隔50ms
    final delay = (widget.index ~/ 8) * 50 + 100;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _isVisible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
