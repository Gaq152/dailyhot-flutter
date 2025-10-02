import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/hot_list_category.dart';
import '../../../providers/hot_list_provider.dart';

class HotCard extends ConsumerStatefulWidget {
  final HotListCategory category;
  final VoidCallback onTap;
  final int index;

  const HotCard({
    super.key,
    required this.category,
    required this.onTap,
    this.index = 0,
  });

  @override
  ConsumerState<HotCard> createState() => _HotCardState();
}

class _HotCardState extends ConsumerState<HotCard> {
  @override
  Widget build(BuildContext context) {
    final hotListAsync = ref.watch(
      hotListProvider(
        HotListParams(type: widget.category.name),
      ),
    );

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: hotListAsync.when(
          data: (data) => Column(
            children: [
              _buildHeader(context, data.subtitle),
              Expanded(child: _buildList(context, data.data.take(5).toList())),
              _buildFooter(context, data.updateTime),
            ],
          ),
          loading: () => Column(
            children: [
              _buildHeader(context, null),
              Expanded(child: _buildLoadingSkeleton()),
              _buildFooter(context, null),
            ],
          ),
          error: (err, stack) => Column(
            children: [
              _buildHeader(context, null),
              Expanded(child: _buildError(ref)),
              _buildFooter(context, '获取失败'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? subtitle) {
    // 根据屏幕宽度调整图标和字体大小
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final iconSize = isMobile ? 24.0 : 32.0;
    final padding = isMobile ? 12.0 : 16.0;
    final spacing = isMobile ? 8.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: [
          // Logo 图标
          ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
            child: Image.asset(
              widget.category.icon,
              width: iconSize,
              height: iconSize,
              cacheWidth: (iconSize * MediaQuery.of(context).devicePixelRatio).toInt(),
              cacheHeight: (iconSize * MediaQuery.of(context).devicePixelRatio).toInt(),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: iconSize,
                  height: iconSize,
                  color: Colors.grey.shade300,
                  child: Icon(Icons.error_outline, size: iconSize * 0.6),
                );
              },
            ),
          ),
          SizedBox(width: spacing),
          // 标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontSize: isMobile ? 10 : 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final horizontalPadding = isMobile ? 10.0 : 16.0;
    final itemSpacing = isMobile ? 6.0 : 8.0;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: itemSpacing),
      itemBuilder: (context, index) {
        final item = items[index];
        return Row(
          children: [
            // 序号
            _buildRankNumber(context, index),
            SizedBox(width: isMobile ? 8 : 12),
            // 标题
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: isMobile ? 12 : 13,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRankNumber(BuildContext context, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    Color? bgColor;
    Color? textColor;

    if (index == 0) {
      bgColor = Colors.red.shade500;
      textColor = Colors.white;
    } else if (index == 1) {
      bgColor = Colors.orange.shade500;
      textColor = Colors.white;
    } else if (index == 2) {
      bgColor = Colors.yellow.shade700;
      textColor = Colors.white;
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    final size = isMobile ? 18.0 : 20.0;
    final fontSize = isMobile ? 10.0 : 12.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 4 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isMobile ? 28 : 40,
              color: Colors.orange.shade400,
            ),
            SizedBox(height: isMobile ? 4 : 8),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 10),
            OutlinedButton.icon(
              onPressed: () {
                // invalidate 触发加载动画
                ref.invalidate(
                  hotListProvider(
                    HotListParams(
                      type: widget.category.name,
                      forceRefresh: false,
                    ),
                  ),
                );
                // 同时触发后台强制刷新
                // ignore: unawaited_futures
                ref.read(
                  hotListProvider(
                    HotListParams(
                      type: widget.category.name,
                      forceRefresh: true,
                    ),
                  ).future,
                );
              },
              icon: Icon(Icons.refresh, size: isMobile ? 11 : 14),
              label: Text('重试', style: TextStyle(fontSize: isMobile ? 9 : 11)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 10,
                  vertical: isMobile ? 1 : 4,
                ),
                minimumSize: Size(0, isMobile ? 22 : 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String? updateTime) {
    final formattedTime = _formatUpdateTime(updateTime);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              formattedTime,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  String _formatUpdateTime(String? updateTime) {
    if (updateTime == null) return '加载中...';

    // 如果是错误信息，直接返回
    if (updateTime == '获取失败' || updateTime == '加载失败') {
      return updateTime;
    }

    try {
      final dateTime = DateTime.parse(updateTime);
      final now = DateTime.now();
      final localTime = dateTime.toLocal();
      final difference = now.difference(localTime);

      if (difference.inMinutes < 1) {
        return '刚刚更新';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分钟前更新';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小时前更新';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前更新';
      } else {
        return '${localTime.month}-${localTime.day} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}更新';
      }
    } catch (e) {
      return '加载失败';
    }
  }
}
