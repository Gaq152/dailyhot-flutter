import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/hot_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/hot_list_category.dart';
import '../../../data/models/hot_list_item.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _keyword = value.trim());
    });
  }

  /// 搜索所有可见分类中已缓存的热榜条目
  List<_SearchGroup> _search(String keyword, List<HotListCategory> categories) {
    if (keyword.isEmpty) return const [];
    final lower = keyword.toLowerCase();
    final groups = <_SearchGroup>[];

    for (final category in categories) {
      // 仅读取已缓存数据，未加载的分类跳过（避免触发一堆网络请求）
      final async = ref.read(hotListProvider(HotListParams(type: category.name)));
      final response = async.valueOrNull?.data;
      if (response == null) continue;

      final matched = <HotListItem>[];
      for (final item in response.data) {
        final titleMatch = item.title.toLowerCase().contains(lower);
        final descMatch =
            item.desc != null && item.desc!.toLowerCase().contains(lower);
        if (titleMatch || descMatch) {
          matched.add(item);
          if (matched.length >= 30) break;
        }
      }

      if (matched.isNotEmpty) {
        groups.add(_SearchGroup(category: category, items: matched));
      }
    }

    return groups;
  }

  /// 过滤匹配关键字的平台本身（搜 "微博" 命中微博平台卡）
  List<HotListCategory> _matchedCategories(
    String keyword,
    List<HotListCategory> categories,
  ) {
    if (keyword.isEmpty) return const [];
    final lower = keyword.toLowerCase();
    return categories
        .where((c) =>
            c.label.toLowerCase().contains(lower) ||
            c.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final categories = settings.categories
        .where((c) => c.show)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final matchedCategories = _matchedCategories(_keyword, categories);
    final groups = _search(_keyword, categories);
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: '返回',
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: '搜索所有榜单中的热点',
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(
        keyword: _keyword,
        matchedCategories: matchedCategories,
        groups: groups,
        totalItems: totalItems,
      ),
    );
  }

  Widget _buildBody({
    required String keyword,
    required List<HotListCategory> matchedCategories,
    required List<_SearchGroup> groups,
    required int totalItems,
  }) {
    if (keyword.isEmpty) {
      return const _SearchHint();
    }

    if (matchedCategories.isEmpty && groups.isEmpty) {
      return _EmptyState(keyword: keyword);
    }

    return CustomScrollView(
      slivers: [
        if (matchedCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: _CategorySection(
              categories: matchedCategories,
              onTap: (c) => context.push('/list/${c.name}'),
            ),
          ),
        if (groups.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '匹配条目 $totalItems 条',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _GroupHeader(category: group.category, count: group.items.length),
              ),
              SliverList.builder(
                itemCount: group.items.length,
                itemBuilder: (context, index) {
                  final item = group.items[index];
                  return _ResultItem(
                    item: item,
                    keyword: keyword,
                    onTap: () => _openDetail(item, group.category),
                    onShare: () => _share(item),
                  );
                },
              ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _openDetail(HotListItem item, HotListCategory category) {
    context.push('/detail', extra: {
      'item': item,
      'categoryIcon': category.icon,
      'categoryLabel': category.label,
    });
  }

  Future<void> _share(HotListItem item) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '${item.title}\n${item.url}',
      subject: item.title,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }
}

class _SearchGroup {
  final HotListCategory category;
  final List<HotListItem> items;

  _SearchGroup({required this.category, required this.items});
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: color.withAlpha(120)),
            const SizedBox(height: 16),
            Text(
              '输入关键字搜索全部榜单',
              style: TextStyle(fontSize: 15, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '仅搜索已加载到本地的内容',
              style: TextStyle(fontSize: 12, color: color.withAlpha(160)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String keyword;
  const _EmptyState({required this.keyword});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 64, color: color.withAlpha(120)),
            const SizedBox(height: 16),
            Text(
              '未找到与 "$keyword" 匹配的内容',
              style: TextStyle(fontSize: 15, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '可能对应榜单尚未加载，返回首页浏览后再搜索',
              style: TextStyle(fontSize: 12, color: color.withAlpha(160)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final List<HotListCategory> categories;
  final ValueChanged<HotListCategory> onTap;

  const _CategorySection({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '匹配榜单 ${categories.length} 个',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ActionChip(
                  avatar: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      c.icon,
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) =>
                          Container(width: 20, height: 20, color: Colors.grey.shade300),
                    ),
                  ),
                  label: Text(c.label),
                  onPressed: () => onTap(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final HotListCategory category;
  final int count;

  const _GroupHeader({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Color(category.color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count 条',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final HotListItem item;
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const _ResultItem({
    required this.item,
    required this.keyword,
    required this.onTap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}，长按分享',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onShare,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HighlightedText(
                text: item.title,
                keyword: keyword,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (item.desc != null && item.desc!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _HighlightedText(
                  text: item.desc!,
                  keyword: keyword,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 带关键字高亮的文本
class _HighlightedText extends StatelessWidget {
  final String text;
  final String keyword;
  final TextStyle? style;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.keyword,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    final highlightStyle = style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        );

    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: highlightStyle,
      ));
      start = index + keyword.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
