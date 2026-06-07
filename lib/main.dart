// lib/main.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
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

// 缓存桌面端判断，避免每次 build 执行 try/catch
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

  @override
  void initState() {
    super.initState();
    // 启动 3 秒后静默检测更新
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.read<UpdateProvider>().checkForUpdates(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) return _buildDesktopLayout();
    return _buildMobileLayout();
  }

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
          // Main content — always visible. Fullscreen overlay covers it when active.
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
