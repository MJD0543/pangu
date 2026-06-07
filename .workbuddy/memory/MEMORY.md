# NewPlayer - 跨平台影视应用

## 项目概述
- 跨平台影视应用，覆盖 Android/iOS/Windows/macOS/Linux/TV
- 内嵌 MPV 播放器（media_kit）
- 三模块：影视、电视、系统

## 技术栈
- Flutter 3.29.3 (D:/flutter)
- media_kit + media_kit_video + media_kit_libs_video (MPV播放器)
- sqflite + sqflite_common_ffi (数据库)
- provider (状态管理)
- shared_preferences (设置存储)
- path_provider + path (文件路径)
- url_launcher (URL启动)
- http (网络请求)
- cached_network_image (图片缓存)
- file_picker (文件选择)
- lpinyin (拼音搜索)
- package_info_plus (版本信息)

## 构建环境
- Windows: Visual Studio Community 2026 (D:\Visual Studio)
- CMake: D:\Visual Studio\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe
- Ninja: D:\Visual Studio\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe
- 7-Zip: C:\Program Files\7-Zip\7z.exe
- 需要开启 Windows 开发者模式

## 构建问题与解决
1. media_kit_libs_windows_video 的 CMakeLists.txt 使用 `cmake -E tar xzf` 解压 .7z 文件
   - cmake 不支持 .7z 格式，需要替换为 7z.exe 命令
   - 修改路径：C:\ProgramData\WorkBuddy\chromium-env\6dfn7\Pub\Cache\hosted\pub.dev\media_kit_libs_windows_video-1.0.11\windows\CMakeLists.txt
2. ANGLE.7z 从 GitHub 下载可能失败（网络问题）
   - 解决方案：手动下载/解压到 build\windows\x64\ANGLE 目录
   - CMake 会检测目录是否已存在并跳过下载
3. ⛔ **严禁运行 flutter clean**：会删除 build/ 目录（含手动解压的 ANGLE/ 和 libmpv/）
   - 始终使用增量构建：直接 flutter build windows --release
   - 如需重新编译 RC 资源，手动删除 Runner.res 而非整个 build/
4. libmpv 手动解压后需要额外步骤：CMake 期望头文件在 libmpv/include/ 直接层级
   - 将 libmpv/include/mpv/* 移动到 libmpv/include/
   - 删除空文件夹 libmpv/include/mpv/（CMake 会跳过下载但不会跑 post-extract 脚本）
5. exe 图标格式：使用纯 DIB/BMP 格式 ICO（bpp=32），不依赖 PNG 嵌入
   - 用 Python Pillow 生成各尺寸 RGBA → 手动构建 ICO（BGRA 底向上 + AND mask）
   - ICO 文件大小 ~370KB（无压缩）

## 构建命令
```
cd E:\newplayer
D:\flutter\bin\flutter.bat build windows --release
```
输出：E:\newplayer\build\windows\x64\runner\Release\newplayer.exe (约74MB)

## 测试源
- 影视源: http://caiji.dyttzyapi.com/api.php/provide/vod
- 电视源: https://ghfast.top/https://raw.githubusercontent.com/develop202/migu_video/refs/heads/main/interface.txt

## 关键文件清单
| 文件 | 说明 |
|------|------|
| `lib/main.dart` | 应用入口，Provider 初始化 |
| `lib/screens/movie/movie_screen.dart` | 影视主页，分类栏+卡片网格 |
| `lib/screens/movie/movie_player_screen.dart` | 影视播放页（含右侧详情面板） |
| `lib/screens/tv/tv_screen.dart` | 电视直播页 |
| `lib/screens/system/system_screen.dart` | 系统设置/源管理 |
| `lib/widgets/video_player_widget.dart` | MPV 播放器封装 |
| `lib/providers/app_provider.dart` | 状态管理（Theme/Source/Movie/TV） |
| `lib/services/movie_api_service.dart` | 苹果CMS API 接口 |
| `lib/services/tv_source_service.dart` | M3U/TXT 源解析 |
| `lib/services/database_service.dart` | SQLite 数据库（sqflite_common_ffi） |
| `lib/models/source_model.dart` | 数据模型 |
| `lib/core/strings.dart` | 中文字符串常量 |
| `lib/core/animations.dart` | 共享动画组件 |
| `lib/core/utils.dart` | 公共工具函数（parseInt/parseDouble） |
| `lib/widgets/tv_focus_widget.dart` | TV 焦点导航组件 |

## 重要环境变量
```bash
# 构建时需要设置，避免 Flutter 遥测文件权限错误
export FLUTTER_SUPPRESS_ANALYTICS=true
```
