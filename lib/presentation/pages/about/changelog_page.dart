import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  static const _viewCurrent = 0;
  static const _viewAll = 1;

  String _fullContent = '';
  String _currentVersion = '';
  String? _currentVersionSection;
  int _view = _viewCurrent;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('CHANGELOG.md'),
        PackageInfo.fromPlatform(),
      ]);
      if (!mounted) return;
      final content = results[0] as String;
      final info = results[1] as PackageInfo;
      final section = _extractVersionSection(content, info.version);
      setState(() {
        _fullContent = content;
        _currentVersion = info.version;
        _currentVersionSection = section;
        // 当前版本未录入 CHANGELOG 时，默认直接展示全部
        if (section == null) _view = _viewAll;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// 从 CHANGELOG 中提取指定版本的段落：起于 `## [version]` 行，止于下一个 `## [` 行或 EOF
  String? _extractVersionSection(String content, String version) {
    final startPattern = RegExp(
      r'^## \[' + RegExp.escape(version) + r'\].*$',
      multiLine: true,
    );
    final startMatch = startPattern.firstMatch(content);
    if (startMatch == null) return null;

    final nextPattern = RegExp(r'^## \[', multiLine: true);
    final nextMatch = nextPattern
        .allMatches(content, startMatch.end)
        .firstOrNull;
    final end = nextMatch?.start ?? content.length;

    // 去掉段尾的 `---` 分隔线
    final raw = content.substring(startMatch.start, end);
    return raw.replaceAll(RegExp(r'\n-{3,}\s*$'), '\n').trimRight();
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              const Text('加载更新日志失败'),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasCurrent = _currentVersionSection != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '当前 v$_currentVersion',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const Spacer(),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: _viewCurrent,
                label: const Text('当前版本'),
                enabled: hasCurrent,
              ),
              const ButtonSegment(value: _viewAll, label: Text('全部版本')),
            ],
            selected: {_view},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
            onSelectionChanged: (set) {
              setState(() => _view = set.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isCurrentView =
        _view == _viewCurrent && _currentVersionSection != null;
    final text = isCurrentView ? _currentVersionSection! : _fullContent;

    if (text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _view == _viewCurrent
                ? '当前版本 v$_currentVersion 暂未在 CHANGELOG 中登记'
                : '暂无更新日志',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Markdown(
      data: text,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) _openExternal(href);
      },
    );
  }
}
