import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/settings_provider.dart';
import '../../../data/services/update_service.dart';
import '../about/about_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollButton = false;
  bool _isScrollingDown = true; // true=向下滚动显示向下箭头, false=向上滚动显示向上箭头
  double _lastScrollOffset = 0;
  String _appVersion = '加载中...';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final currentOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // 滚动超过 200 像素时显示按钮
    if (currentOffset > 200 && !_showScrollButton) {
      setState(() => _showScrollButton = true);
    } else if (currentOffset <= 200 && _showScrollButton) {
      setState(() => _showScrollButton = false);
    }

    // 判断箭头方向
    bool shouldShowUpArrow;

    // 接近底部（距离底部小于 300 像素）强制显示向上箭头
    if (currentOffset >= maxScroll - 300) {
      shouldShowUpArrow = true;
    }
    // 接近顶部（小于 500 像素）强制显示向下箭头
    else if (currentOffset < 500) {
      shouldShowUpArrow = false;
    }
    // 在中间区域，根据滚动方向判断
    else {
      if ((currentOffset - _lastScrollOffset).abs() > 10) {
        shouldShowUpArrow = currentOffset < _lastScrollOffset; // 向上滚动显示向上箭头
        _lastScrollOffset = currentOffset;
      } else {
        shouldShowUpArrow = !_isScrollingDown; // 保持当前状态
      }
    }

    if (shouldShowUpArrow != !_isScrollingDown) {
      setState(() => _isScrollingDown = !shouldShowUpArrow);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('全局设置'),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // 基础设置
          _buildSectionTitle('基础设置'),
          const SizedBox(height: 12),

          // 明暗模式
          _buildCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '明暗模式',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Flexible(
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('浅色'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('深色'),
                            ),
                          ],
                          selected: {settings.themeMode == ThemeMode.system
                              ? (MediaQuery.of(context).platformBrightness == Brightness.dark
                                  ? ThemeMode.dark
                                  : ThemeMode.light)
                              : settings.themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            settingsNotifier.setThemeMode(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('明暗模式跟随系统'),
                  subtitle: const Text('明暗模式是否跟随系统当前模式'),
                  value: settings.themeAuto,
                  onChanged: (value) {
                    settingsNotifier.setThemeAuto(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 链接跳转方式
          _buildCard(
            child: SwitchListTile(
              title: const Text('新窗口打开链接'),
              subtitle: const Text('选择榜单列表内容的跳转方式'),
              value: settings.linkOpenExternal,
              onChanged: (value) {
                settingsNotifier.setLinkOpenExternal(value);
              },
            ),
          ),
          const SizedBox(height: 12),

          // 列表文本大小
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '列表文本大小',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '我是将要显示的文字的大小',
                      style: TextStyle(fontSize: settings.listFontSize),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Slider(
                        value: settings.listFontSize,
                        min: 14.0,
                        max: 20.0,
                        divisions: 60,
                        onChanged: (value) {
                          settingsNotifier.setListFontSize(value);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '小一点',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          Text(
                            '最大',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 榜单排序
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '榜单排序',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '拖拽以排序，开关用以控制在页面中的显示状态',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _showRestoreDialog(context, settingsNotifier);
                        },
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: settings.categories.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final categories = List.of(settings.categories);
                    final item = categories.removeAt(oldIndex);
                    categories.insert(newIndex, item);

                    // 更新order
                    for (int i = 0; i < categories.length; i++) {
                      categories[i] = categories[i].copyWith(order: i);
                    }

                    settingsNotifier.updateCategories(categories);
                  },
                  itemBuilder: (context, index) {
                    final category = settings.categories[index];
                    return Card(
                      key: ValueKey(category.name),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            category.icon,
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey.shade300,
                              );
                            },
                          ),
                        ),
                        title: Text(category.label),
                        trailing: Switch(
                          value: category.show,
                          onChanged: (value) {
                            final updatedCategory = category.copyWith(show: value);
                            final updatedCategories = settings.categories
                                .map((c) => c.name == category.name ? updatedCategory : c)
                                .toList();
                            settingsNotifier.updateCategories(updatedCategories);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${category.label}榜单已${value ? "开启" : "关闭"}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 杂项设置
          _buildSectionTitle('杂项设置'),
          const SizedBox(height: 12),

          _buildCard(
            child: ListTile(
              title: const Text('重置所有数据'),
              subtitle: const Text('重置所有数据，你的自定义设置都将会丢失'),
              trailing: FilledButton.tonal(
                onPressed: () {
                  _showResetDialog(context, settingsNotifier);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                ),
                child: const Text('重置'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 关于
          _buildSectionTitle('关于'),
          const SizedBox(height: 12),

          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于应用'),
                  subtitle: Text('版本 $_appVersion'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.system_update),
                  title: const Text('检查更新'),
                  subtitle: const Text('查看是否有新版本'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _checkForUpdates(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 底部版权信息
          Center(
            child: Column(
              children: [
                Text(
                  '© 2025 DailyHot',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ by gaq',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollButton
          ? FloatingActionButton(
              onPressed: _isScrollingDown ? _scrollToBottom : _scrollToTop,
              tooltip: _isScrollingDown ? '前往底部' : '回到顶部',
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  _isScrollingDown ? Icons.arrow_downward : Icons.arrow_upward,
                  key: ValueKey(_isScrollingDown),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  void _showRestoreDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认'),
        content: const Text('确认将排序恢复到默认状态？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              notifier.restoreDefaultCategories();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('恢复默认榜单排序成功'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置所有数据'),
        content: const Text('确认重置所有数据？你的自定义设置都将会丢失！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              notifier.resetAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已重置所有设置'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkUpdate();

      // 关闭加载对话框
      if (context.mounted) Navigator.pop(context);

      if (updateInfo != null) {
        // 有新版本
        // ignore: use_build_context_synchronously
        _showUpdateDialog(context, updateInfo);
      } else {
        // 已是最新版本
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前已是最新版本'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) Navigator.pop(context);

      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.orange.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '发现新版本',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 版本号标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'v${updateInfo.version}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 更新内容
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.new_releases,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '更新内容',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        updateInfo.changelog,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 发布时间
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '发布于 ${_formatDate(updateInfo.publishedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(updateInfo.downloadUrl);
            },
            icon: const Icon(Icons.download, size: 20),
            label: const Text('立即下载'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
