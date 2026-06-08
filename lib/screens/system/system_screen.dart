// lib/screens/system/system_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/update_provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import 'resource_library_screen.dart';
import 'history_screen.dart';
import 'tvbox_subscribe_dialog.dart';
import 'data_transfer_screen.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});
  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  String _version = '1.0.0';
  UpdateStatus? _lastNotifiedStatus;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSilentUpdate();
      context.read<SourceProvider>().loadTeenModeSettings();
    });
  }

  /// 如果静默检测已完成且有新版本，弹窗提示
  void _checkSilentUpdate() {
    final prov = context.read<UpdateProvider>();
    if (prov.status == UpdateStatus.available &&
        _lastNotifiedStatus != UpdateStatus.available) {
      _lastNotifiedStatus = UpdateStatus.available;
      _showUpdateDialog(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次依赖变化时也检查（例如从其他页面切回来）
    final status = context.read<UpdateProvider>().status;
    if (status == UpdateStatus.available &&
        _lastNotifiedStatus != UpdateStatus.available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSilentUpdate();
      });
    }
  }

  @override
  void dispose() {
    _lastNotifiedStatus = null;
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/app_icon.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text(S.settings, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: System
          _buildSectionTitle(S.system),
          _buildAppearanceItem(cardColor),
          _buildSettingItem(
            title: S.watchHistory,
            icon: Icons.history,
            showArrow: true,
            onTap: () => _openHistory(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.clearCache,
            icon: Icons.cleaning_services_outlined,
            showArrow: true,
            onTap: () => _clearCache(context),
            cardColor: cardColor,
          ),
          const SizedBox(height: 16),
          // Section: Server
          _buildSectionTitle(S.server),
          _buildTeenModeItem(cardColor),
          _buildSettingItem(
            title: S.resourceLibrary,
            icon: Icons.storage_outlined,
            showArrow: true,
            onTap: () => _openResourceLibrary(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.tvboxSubscribe,
            icon: Icons.subscriptions_outlined,
            showArrow: true,
            onTap: () => _openTvboxSubscribe(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: '数据互传',
            icon: Icons.swap_horiz,
            showArrow: true,
            onTap: () => _openDataTransfer(context),
            cardColor: cardColor,
          ),
          const SizedBox(height: 16),
          // Section: Player
          _buildSectionTitle(S.player),
          _buildSettingItem(
            title: S.core,
            icon: Icons.memory_outlined,
            trailingText: 'MPV',
            onTap: () {},
            cardColor: cardColor,
          ),
          const SizedBox(height: 16),
          // Section: About
          _buildSectionTitle(S.about),
          _buildSettingItem(
            title: S.homepage,
            icon: Icons.open_in_browser,
            showArrow: true,
            onTap: () => _launchUrl('https://github.com/MJD0543/pangu'),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.license,
            icon: Icons.description_outlined,
            showArrow: true,
            onTap: () => _showLicenseDialog(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.version,
            icon: Icons.info_outline,
            trailingText: _version,
            onTap: () {},
            cardColor: cardColor,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    String? trailingText,
    bool showArrow = false,
    IconData? icon,
    required VoidCallback onTap,
    required Color cardColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: icon != null
          ? Icon(icon, size: 18, color: AppTheme.primaryColor)
          : null,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            if (showArrow)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAppearanceItem(Color cardColor) {
    final themeProv = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 16, right: 12),
        leading: const Icon(Icons.palette_outlined, size: 18, color: AppTheme.primaryColor),
        title: Text(
          S.appearance,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeChip(S.auto, themeProv.mode == ThemeMode.system, () => themeProv.setMode(ThemeMode.system)),
            const SizedBox(width: 4),
            Text('|', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
            const SizedBox(width: 4),
            _buildThemeChip(S.light, themeProv.mode == ThemeMode.light, () => themeProv.setMode(ThemeMode.light)),
            const SizedBox(width: 4),
            Text('|', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
            const SizedBox(width: 4),
            _buildThemeChip(S.dark, themeProv.mode == ThemeMode.dark, () => themeProv.setMode(ThemeMode.dark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeenModeItem(Color cardColor) {
    // Ensure settings are loaded (call once via the initState)
    return Consumer<SourceProvider>(
      builder: (ctx, srcProv, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 16, right: 12),
            secondary: const Icon(Icons.family_restroom, size: 18, color: AppTheme.primaryColor),
            title: Text(S.teenMode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            value: srcProv.teenModeEnabled,
            onChanged: (val) {
              if (val) {
                _showTeenModeEnableDialog(ctx, srcProv);
              } else {
                _showTeenModeDisableDialog(ctx, srcProv);
              }
            },
          ),
        );
      },
    );
  }

  void _showTeenModeEnableDialog(BuildContext ctx, SourceProvider srcProv) {
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(S.teenModeEnable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: S.teenModeSetPassword,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: S.teenModeConfirmPassword,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.cancel)),
          ElevatedButton(
            onPressed: () {
              final pwd = pwdCtrl.text.trim();
              if (pwd.isEmpty || pwd != confirmCtrl.text.trim()) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(S.teenModePasswordMismatch)));
                return;
              }
              srcProv.enableTeenMode(pwd);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(S.teenModeEnabledHint)));
            },
            child: Text(S.confirm),
          ),
        ],
      ),
    );
  }

  void _showTeenModeDisableDialog(BuildContext ctx, SourceProvider srcProv) {
    final pwdCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(S.teenModeDisableConfirm),
        content: TextField(
          controller: pwdCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: S.teenModeEnterPassword,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.cancel)),
          ElevatedButton(
            onPressed: () async {
              final success = await srcProv.disableTeenMode(pwdCtrl.text.trim());
              if (success) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('青少年模式已关闭')));
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(S.teenModeWrongPassword)));
              }
            },
            child: Text(S.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _openResourceLibrary(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => const ResourceLibraryScreen(),
    ));
  }

  void _openDataTransfer(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => const DataTransferScreen(),
    ));
  }

  void _openTvboxSubscribe(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const TvboxSubscribeDialog(),
    );
  }

  void _openHistory(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => const HistoryScreen(),
    ));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicensePage(BuildContext ctx) {
    showLicensePage(
      context: ctx,
      applicationName: S.appName,
      applicationVersion: _version,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showLicenseDialog(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    showDialog(
      context: ctx,
      builder: (ctx2) => AlertDialog(
        title: Text(S.license),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _licenseText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }

  static const _licenseText = '''欢迎使用 [盘古影视]（以下简称"本应用"）！

在使用本应用之前，请仔细阅读并理解本免责声明。使用本应用即表示您已完全接受并同意遵守本声明的所有条款和条件。如果您不同意本声明中的任何条款，请停止使用本应用。

1. 应用功能说明

本应用是一款免费工具，旨在为用户提供便捷的方式，通过用户自行配置的苹果CMS、IPTV等服务来展示、搜索和播放影片。本应用本身不托管、存储或分发任何影视内容，也不提供任何影视资源或相关链接。所有内容的获取、展示和播放均由用户提供的苹果CMS、IPTV服务决定。

2. 数据收集与隐私保护

本应用严格遵守隐私保护原则，不会收集、存储或传输任何用户的个人信息或数据。您的所有操作（如连接到苹果CMS、IPTV等服务）均在本地设备上完成，且所有数据流均直接与您所配置的服务进行交互，本应用不会对数据进行任何形式的记录或转发。

3. 内容来源的责任

本应用仅为技术工具，不参与也未授权任何内容的分发或传播。您通过本应用查看或播放的任何内容，均来源于您自行配置的苹果CMS、IPTV等服务。您需要确保这些服务中包含的内容是合法的，并符合您所在地区的法律法规。对于任何非法内容或未经授权的使用行为，本应用概不负责。

4. 版权与合法性

本应用尊重知识产权和版权法律。请您确保通过本应用访问的内容具有合法的版权许可或观看权限。如因观看或使用未经授权的内容而引发的任何法律纠纷或责任，均由用户自行承担，与本应用及其开发者无关。

5. 技术支持与责任限制

本应用尽力提供稳定、可靠的技术支持，但不对以下事项承担责任：

- 您使用的苹果CMS、IPTV等服务的可用性、稳定性或安全性；
- 因网络问题或第三方服务故障导致的播放中断或其他问题；
- 您设备上的任何数据丢失或损坏；
- 因使用本应用而导致的任何直接、间接、特殊或衍生性损失。

6. 用户责任

作为本应用的用户，您需对自己的行为负责。请确保您：

- 配置的内容服务符合当地法律法规；
- 对通过本应用访问的内容享有合法的观看权限；
- 妥善保管自己的账户信息和密码，防止未经授权的使用。

7. 更新与修改

我们保留随时修改本免责声明的权利。如有任何更新，我们将通过适当的方式通知您。您继续使用本应用即视为接受更新后的免责声明。


感谢您选择 [盘古影视]！我们希望为您提供一个安全、便捷的观影体验。请务必合法、合规地使用本应用。''';

  Future<void> _clearCache(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('将清除图片缓存和临时文件，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text(S.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: const Text('清理', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
    if (confirm != true || !ctx.mounted) return;

    try {
      // 清理 cached_network_image 缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      // 清理临时文件
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entry in tempDir.listSync()) {
          try {
            if (entry is File) {
              await entry.delete();
            } else if (entry is Directory) {
              await entry.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text(S.cacheCleared), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('清理失败: $e')),
        );
      }
    }
  }

  // ==================== 更新检测/下载/安装 ====================
  Future<void> _checkForUpdatesManually(BuildContext ctx) async {
    final prov = ctx.read<UpdateProvider>();
    if (prov.status == UpdateStatus.checking) return;

    await prov.checkForUpdates(silent: false);

    if (!ctx.mounted) return;

    if (prov.status == UpdateStatus.available) {
      await _showUpdateDialog(ctx);
    } else if (prov.status == UpdateStatus.error) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(prov.errorMessage)),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('已经是最新版本')),
      );
    }
  }

  Future<void> _showUpdateDialog(BuildContext ctx) async {
    final prov = ctx.read<UpdateProvider>();
    final themeProv = ctx.read<ThemeProvider>();
    final isDark = themeProv.mode == ThemeMode.dark;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: !prov.mandatory,
      builder: (dialogCtx) {
        final dialogProv = ctx.read<UpdateProvider>();
        return AlertDialog(
          title: const Text('发现新版本'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('新版本：${dialogProv.latestVersion}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (dialogProv.changelog.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogProv.changelog,
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (!dialogProv.mandatory)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('稍后再说'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _startDownload(ctx);
              },
              child: const Text('立即下载'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDownload(BuildContext ctx) async {
    final prov = ctx.read<UpdateProvider>();
    await prov.downloadUpdate();

    if (!ctx.mounted) return;

    if (prov.status == UpdateStatus.downloaded) {
      await _showInstallDialog(ctx);
    } else if (prov.status == UpdateStatus.error) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(prov.errorMessage)),
      );
    }
  }

  Future<void> _showInstallDialog(BuildContext ctx) async {
    final prov = ctx.read<UpdateProvider>();
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('下载完成'),
          content: const Text('安装包已下载完成，点击"安装"将关闭应用并运行安装程序。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('稍后再说'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                prov.installUpdate();
              },
              child: const Text('立即安装'),
            ),
          ],
        );
      },
    );
  }
}
