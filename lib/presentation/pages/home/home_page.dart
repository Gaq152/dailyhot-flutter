import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hot_list_provider.dart';
import '../../providers/settings_provider.dart';
import 'widgets/hot_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final categories = settings.categories
        .where((c) => c.show)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
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

              // 等待动画淡出
              await Future.delayed(const Duration(milliseconds: 200));

              // 刷新所有显示的榜单数据
              final settings = ref.read(settingsProvider);
              final categories = settings.categories.where((c) => c.show).toList();

              // 刷新所有榜单
              for (int i = 0; i < categories.length; i++) {
                final categoryName = categories[i].name;

                // invalidate 并触发刷新
                ref.invalidate(
                  hotListProvider(
                    HotListParams(type: categoryName, forceRefresh: false),
                  ),
                );

                // 触发强制刷新
                // ignore: unawaited_futures
                ref.read(
                  hotListProvider(
                    HotListParams(type: categoryName, forceRefresh: true),
                  ).future,
                );
              }

              // 等待刷新完成
              await Future.delayed(const Duration(milliseconds: 500));

              if (mounted) {
                setState(() => _isRefreshing = false);
              }
            },
            tooltip: '刷新所有榜单',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: '设置',
          ),
        ],
      ),
      body: LayoutBuilder(
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
            aspectRatio = 0.75;  // 卡片稍高
            spacing = 12;
          }

          return AnimatedOpacity(
            opacity: _isRefreshing ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: GridView.builder(
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
                  child: HotCard(
                    category: category,
                    index: index,
                    onTap: () => context.push('/list/${category.name}'),
                  ),
                );
              },
            ),
          );
        },
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
        // 标题和日期时间
        Flexible(
          child: StreamBuilder<DateTime>(
            stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
            initialData: DateTime.now(),
            builder: (context, snapshot) {
              final now = snapshot.data!;
              final weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][now.weekday % 7];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '今日热榜',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $weekday',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',  // 使用等宽字体
                      fontFeatures: const [
                        FontFeature.tabularFigures(),  // 表格数字（等宽数字）
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ],
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
  void didUpdateWidget(_AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 刷新时重新触发动画
    if (!oldWidget.isRefreshing && widget.isRefreshing) {
      setState(() => _isVisible = false);
    } else if (oldWidget.isRefreshing && !widget.isRefreshing) {
      // 刷新完成，逐个显示
      final delay = (widget.index ~/ 4) * 30 + 100;
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
