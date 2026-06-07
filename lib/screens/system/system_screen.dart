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
            trailingText: 'MPV (media_kit)',
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
            onTap: () => _launchUrl('https://github.com'),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.license,
            icon: Icons.description_outlined,
            showArrow: true,
            onTap: () => _showLicensePage(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: S.sponsor,
            icon: Icons.favorite_outline,
            showArrow: true,
            onTap: () => _showSponsorDialog(context),
            cardColor: cardColor,
          ),
          _buildSettingItem(
            title: '检测更新',
            icon: Icons.system_update_outlined,
            trailingText: context.watch<UpdateProvider>().status == UpdateStatus.checking
                ? '检测中...'
                : null,
            showArrow: true,
            onTap: () => _checkForUpdatesManually(context),
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

  void _showSponsorDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (ctx2) => AlertDialog(
        title: Text(S.sponsorSupport),
        content: Text(S.sponsorContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }

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
