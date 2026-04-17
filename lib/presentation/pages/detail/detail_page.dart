import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/hot_list_item.dart';

/// 热榜详情页
class DetailPage extends StatelessWidget {
  final HotListItem item;
  final String? categoryIcon;
  final String? categoryLabel;

  const DetailPage({
    super.key,
    required this.item,
    this.categoryIcon,
    this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDesc = item.desc != null &&
        item.desc!.isNotEmpty &&
        !_isPlaceholderDesc(item.desc!);

    // 预处理 desc 内容，使其更适合 Markdown 渲染
    final processedDesc = hasDesc ? _preprocessMarkdown(item.desc!) : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel ?? '详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
            tooltip: '分享',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openInBrowser(context),
            tooltip: '在浏览器中打开',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            if (item.cover != null && item.cover!.isNotEmpty)
              Semantics(
                image: true,
                label: '${item.title} 封面图',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.cover!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 标题
            Text(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 作者和热度信息
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (item.author != null && item.author!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.author!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                if (item.hot != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.hotText,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // 分隔线
            Divider(color: theme.dividerColor),

            const SizedBox(height: 16),

            // 内容描述
            if (hasDesc) ...[
              Text(
                '简介',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // 使用 Markdown 渲染，支持格式化文本、链接、表情等
              MarkdownBody(
                data: processedDesc,
                selectable: true,
                sizedImageBuilder: (config) {
                  // 使用 CachedNetworkImage 加载图片，支持缓存和加载动画
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: config.uri.toString(),
                        width: config.width ?? double.infinity,
                        height: config.height,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: config.height ?? 150,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: config.height ?? 100,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 32,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '图片加载失败',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface,
                  ),
                  h1: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  h2: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  h3: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  blockquote: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary.withAlpha(128),
                        width: 4,
                      ),
                    ),
                  ),
                  code: TextStyle(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无详情内容',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击下方按钮在浏览器中查看完整内容',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 在浏览器中打开按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openInBrowser(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('在浏览器中打开'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 预处理 Markdown 内容
  /// 将各种格式转换为标准 Markdown 以便正确渲染
  String _preprocessMarkdown(String text) {
    var result = text;

    // 0. 处理转义的换行符 \n -> 真正的换行（在其他处理之前）
    // 注意：这里处理的是字面的两个字符 '\' 和 'n'
    result = result.replaceAll(r'\n', '\n');

    // 1. 检测并保护 ASCII 流程图/表格（包含 box drawing 字符）
    // 将其包裹在代码块中以保持格式
    result = _protectAsciiArt(result);

    // 2. 确保单个换行符在 Markdown 中也能生效（但跳过代码块）
    // 标准 Markdown 需要两个换行才能产生段落
    result = _doubleNewlinesOutsideCodeBlocks(result);

    // 3. 处理 Obsidian 风格的 callout 语法
    result = result.replaceAllMapped(
      RegExp(r'\[!(\w+)\]', caseSensitive: false),
      (match) {
        final type = match.group(1)?.toLowerCase() ?? '';
        switch (type) {
          case 'warning':
            return '⚠️ **警告**';
          case 'error':
            return '❌ **错误**';
          case 'success':
            return '✅ **成功**';
          case 'info':
            return 'ℹ️ **信息**';
          case 'note':
            return '📝 **注意**';
          case 'tip':
            return '💡 **提示**';
          default:
            return '📌 **$type**';
        }
      },
    );

    // 4. 处理 "GitHub - user/repo:" 格式，转换为可点击链接
    result = result.replaceAllMapped(
      RegExp(r'GitHub(?:\s*:\s*GitHub)?\s*-\s*([a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)\s*:', caseSensitive: false),
      (match) {
        final repo = match.group(1) ?? '';
        return '**[GitHub - $repo](https://github.com/$repo)**:';
      },
    );

    // 5. 清理爬取的页面噪音文本（如独立的按钮文字）
    result = result.replaceAll(RegExp(r'\n\s*Star\s*\n'), '\n');
    result = result.replaceAll(RegExp(r'\n\s*Fork\s*\n'), '\n');
    result = result.replaceAll(RegExp(r'\n\s*Watch\s*\n'), '\n');

    // 6. 将裸 URL 转换为 Markdown 格式
    // 图片链接转为 ![](url)，其他链接转为 [domain](url)
    result = result.replaceAllMapped(
      RegExp(r'(?<!\]\()(?<!\[!?\]\()(?<!\[)(https?://[^\s\)\]\n]+)'),
      (match) {
        final url = match.group(0) ?? '';
        try {
          final uri = Uri.parse(url);
          final path = uri.path.toLowerCase();

          // 检查是否为图片链接
          if (path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png') ||
              path.endsWith('.gif') ||
              path.endsWith('.webp') ||
              path.endsWith('.svg') ||
              path.endsWith('.bmp')) {
            return '![]($url)';
          }

          // 普通链接
          final displayText = uri.host.replaceFirst('www.', '');
          return '[$displayText]($url)';
        } catch (_) {
          return '[$url]($url)';
        }
      },
    );

    // 7. 处理连续的空行，保留最多2个
    result = result.replaceAll(RegExp(r'\n{4,}'), '\n\n');

    // 8. 处理可能的 HTML 实体
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');

    return result.trim();
  }

  /// 保护 ASCII 艺术（流程图、表格等）
  /// 检测包含 box drawing 字符的连续行，将其包裹在代码块中
  String _protectAsciiArt(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    var inAsciiBlock = false;
    var asciiBuffer = <String>[];

    // Box drawing 字符和常见流程图符号
    final asciiArtPattern = RegExp(
      r'[┌┐└┘├┤┬┴┼─│═║╔╗╚╝╠╣╦╩╬░▒▓█▄▀■□●○◆◇→←↑↓↔↕∥]|'
      r'\+[-=]+\+|'  // +---+ 风格
      r'\|.*\|',     // |...| 风格
    );

    for (final line in lines) {
      final hasAsciiArt = asciiArtPattern.hasMatch(line);

      if (hasAsciiArt) {
        if (!inAsciiBlock) {
          inAsciiBlock = true;
          asciiBuffer = [];
        }
        asciiBuffer.add(line);
      } else {
        if (inAsciiBlock) {
          // 结束 ASCII 块，输出为代码块
          if (asciiBuffer.isNotEmpty) {
            result.add('```');
            result.addAll(asciiBuffer);
            result.add('```');
          }
          inAsciiBlock = false;
          asciiBuffer = [];
        }
        result.add(line);
      }
    }

    // 处理末尾的 ASCII 块
    if (inAsciiBlock && asciiBuffer.isNotEmpty) {
      result.add('```');
      result.addAll(asciiBuffer);
      result.add('```');
    }

    return result.join('\n');
  }

  /// 在代码块外部将单换行转为双换行，保持代码块内格式不变
  String _doubleNewlinesOutsideCodeBlocks(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    var inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 检测代码块边界
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        result.add(line);
        continue;
      }

      result.add(line);

      // 在代码块外部，非空行后添加额外换行
      if (!inCodeBlock && line.trim().isNotEmpty && i < lines.length - 1) {
        // 下一行不是代码块开始，且不是已经的空行
        final nextLine = lines[i + 1];
        if (!nextLine.trim().startsWith('```') && nextLine.trim().isNotEmpty) {
          result.add('');
        }
      }
    }

    return result.join('\n');
  }

  /// 检查是否为无意义的占位文本
  bool _isPlaceholderDesc(String desc) {
    const placeholders = [
      '该视频暂无简介',
      '暂无简介',
      '-',
      '无',
      'null',
      '暂无描述',
      '暂无内容',
    ];
    final trimmed = desc.trim();
    return placeholders.contains(trimmed) || trimmed.length < 2;
  }

  /// 分享标题和链接
  Future<void> _share(BuildContext context) async {
    final content = '${item.title}\n${item.url}';
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      content,
      subject: item.title,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  /// 在浏览器中打开
  Future<void> _openInBrowser(BuildContext context) async {
    final url = item.url;
    final uri = Uri.parse(url);
    String? videoId;

    // 检测抖音热榜链接且在Android平台
    if (Platform.isAndroid &&
        uri.host.contains('douyin.com') &&
        uri.path.startsWith('/hot/')) {
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

        if (csrfToken != null) {
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
              debugPrint('启动抖音APP失败: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('抖音链接处理失败: $e');
      }
    }

    // 降级：浏览器打开
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
