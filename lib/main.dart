// lib/main.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'providers/app_provider.dart';
import 'screens/movie/movie_screen.dart';
import 'screens/tv/tv_screen.dart';
import 'screens/system/system_screen.dart';
import 'widgets/tv_focus_widget.dart';
import 'providers/update_provider.dart';
import 'services/database_service.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseService.initFfi();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SourceProvider()),
        ChangeNotifierProvider(create: (_) => MovieProvider()),
        ChangeNotifierProvider(create: (_) => TvProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProv, __) => MaterialApp(
          title: '盘古影视',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProv.mode,
          home: const TvBackHandler(child: MainShell()),
        ),
      ),
    );
  }
}

// 缓存桌面端判断
final bool _isDesktop = (() {
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (_) {
    return false;
  }
})();

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isTV = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detectTV();
    // 启动 3 秒后静默检测更新
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.read<UpdateProvider>().checkForUpdates(silent: true);
      }
    });
  }

  /// 检测是否为 Android TV 设备
  Future<void> _detectTV() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // Android TV 有 android.software.leanback 系统特性，且通常没有触摸屏
      final hasLeanback = androidInfo.systemFeatures.contains('android.software.leanback');
      final hasTouchscreen = androidInfo.systemFeatures.contains('android.hardware.touchscreen');
      final isTV = hasLeanback || (!hasTouchscreen && _isDesktop == false);
      if (mounted) setState(() { _isTV = isTV; _isLoading = false; });
    } catch (_) {
      // 检测失败时退回到宽高比启发式判断（TV 通常 16:9 且宽度 >= 720）
      if (mounted) {
        final mediaSize = MediaQuery.of(context).size;
        final isTVHeuristic = mediaSize.width >= 720 &&
            (mediaSize.width / mediaSize.height) >= 1.3;
        setState(() { _isTV = isTVHeuristic; _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isDesktop) return _buildDesktopLayout();
    if (_isTV) return _buildTVLayout();
    return _buildMobileLayout();
  }

  // ============ 桌面端布局（左侧边栏导航） ============
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1F) : const Color(0xFFF5F5FA);
    final unselectedColor = isDark ? const Color(0xFF8888A0) : const Color(0xFF666680);

    final destinations = [
      _NavItem(icon: Icons.movie_outlined, selectedIcon: Icons.movie, label: S.movie),
      _NavItem(icon: Icons.live_tv_outlined, selectedIcon: Icons.live_tv, label: S.tv),
      _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: S.system),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar
          Container(
            width: 72,
            color: bgColor,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.5),
                    child: Image.asset('assets/icons/app_icon.png', width: 48, height: 48, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Column(
                    children: List.generate(destinations.length, (i) {
                      final item = destinations[i];
                      final selected = _currentIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        child: Tooltip(
                          message: item.label,
                          child: TvFocusWrapper(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _currentIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: selected ? AppTheme.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                selected ? item.selectedIcon : item.icon,
                                color: selected ? Colors.white : unselectedColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const MovieScreen(),
                TvScreen(isActive: _currentIndex == 1),
                const SystemScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ Android TV 布局（Leanback 顶部水平标签导航） ============
  Widget _buildTVLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1F) : const Color(0xFFF5F5FA);
    final unselectedColor = isDark ? const Color(0xFF8888A0) : const Color(0xFF666680);

    final tabs = [
      _NavItem(icon: Icons.movie_outlined, selectedIcon: Icons.movie, label: S.movie),
      _NavItem(icon: Icons.live_tv_outlined, selectedIcon: Icons.live_tv, label: S.tv),
      _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: S.system),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Top Leanback tab bar
          Container(
            height: 64,
            color: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // App icon
                Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.8),
                    child: Image.asset('assets/icons/app_icon.png', width: 36, height: 36, fit: BoxFit.cover),
                  ),
                ),
                // Tab buttons
                ...List.generate(tabs.length, (i) {
                  final item = tabs[i];
                  final selected = _currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TvFocusWrapper(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _currentIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              color: selected ? Colors.white : unselectedColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected ? Colors.white : unselectedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const MovieScreen(),
                TvScreen(isActive: _currentIndex == 1),
                const SystemScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 手机/平板布局（底部导航栏） ============
  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const MovieScreen(),
          TvScreen(isActive: _currentIndex == 1),
          const SystemScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.movie_outlined),
            selectedIcon: const Icon(Icons.movie),
            label: S.movie,
          ),
          NavigationDestination(
            icon: const Icon(Icons.live_tv_outlined),
            selectedIcon: const Icon(Icons.live_tv),
            label: S.tv,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: S.system,
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  _NavItem({required this.icon, required this.selectedIcon, required this.label});
}
