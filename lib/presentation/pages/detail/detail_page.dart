import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel ?? '详情'),
        actions: [
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
              ClipRRect(
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
                data: item.desc!,
                selectable: true,
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
