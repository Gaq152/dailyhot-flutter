import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = '加载中...';

  @override
  void initState() {
    super.initState();
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于应用'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // 应用图标
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.local_fire_department,
                size: 80,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // 应用名称
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 版本号
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'v$_appVersion',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 应用描述
            Text(
              '每日热点聚合应用',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // 版权信息
            Text(
              '© 2025 DailyHot',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),

            // 功能卡片
            _buildCard(
              child: Column(
                children: [
                  // 开发者信息
                  _buildInfoItem(
                    icon: Icons.code,
                    iconColor: Colors.blue.shade600,
                    title: '开发者',
                    subtitle: 'gaq',
                  ),
                  const Divider(height: 1, indent: 56),

                  // GitHub 仓库
                  _buildInfoItem(
                    icon: Icons.public,
                    iconColor: Colors.green.shade600,
                    title: 'GitHub 仓库',
                    subtitle: 'Gaq152/dailyhot-flutter',
                    onTap: () => _launchUrl('https://github.com/Gaq152/dailyhot-flutter'),
                  ),
                  const Divider(height: 1, indent: 56),

                  // 反馈与建议
                  _buildInfoItem(
                    icon: Icons.feedback_outlined,
                    iconColor: Colors.purple.shade600,
                    title: '反馈与建议',
                    subtitle: '报告问题或提出功能建议',
                    onTap: () => _launchUrl('https://github.com/Gaq152/dailyhot-flutter/issues'),
                  ),
                  const Divider(height: 1, indent: 56),

                  // 开源许可证
                  _buildInfoItem(
                    icon: Icons.description_outlined,
                    iconColor: Colors.orange.shade600,
                    title: '开源许可证',
                    subtitle: '查看使用的第三方库许可',
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: _appVersion,
                        applicationLegalese: '© 2025 DailyHot',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 技术栈信息
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build_outlined, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '技术栈',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTechChip('Flutter', Colors.blue),
                        _buildTechChip('Riverpod', Colors.purple),
                        _buildTechChip('Dio', Colors.orange),
                        _buildTechChip('Hive', Colors.yellow.shade700),
                        _buildTechChip('Material Design 3', Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 底部说明
            Text(
              '感谢使用每日热点',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildTechChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
