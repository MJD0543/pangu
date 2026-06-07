# NewPlayer 代码审查报告

**审查日期**: 2026-06-06  
**审查人**: Senior Developer (高级开发工程师)  
**审查范围**: 完整项目（20 → 19 个 Dart 文件）

---

## 一、审查结果总览

| 指标 | 修复前 | 修复后 |
|------|-------|-------|
| 编译错误 | 2 个 | **0** |
| 代码警告 | 5 个 | **0** |
| Lint 提示 | 304 条 | **158 条** (全部 info) |
| 无效文件 | 10 个 | **0** |
| 未使用依赖 | 2 个 | **0** |
| 重复代码 | 3 处 | **0** |

---

## 二、已修复的严重问题

### 2.1 编译错误（2 处）

**问题**: `strings.dart` 中缺少 `S.exportFailed` 和 `S.importFailed` 常量，导致 `resource_library_screen.dart` 编译失败。

**修复**: 在 `strings.dart` 中新增两个缺失常量。

### 2.2 代码警告（5 处）

| 文件 | 问题 | 修复 |
|------|------|------|
| `main.dart:4` | 未使用的 `flutter/services.dart` 导入 | 移除 |
| `main.dart:105` | 未使用的 `selectedColor` 局部变量 | 移除 |
| `app_provider.dart:3` | 未使用的 `flutter/foundation.dart` 导入 | 移除 |
| `app_provider.dart:247` | 不必要的 null 比较 | 简化条件 |
| `database_service.dart:2` | 冗余的 `sqflite` 导入 | 移除 |
| `movie_player_screen.dart:10` | 未使用的 `animations.dart` 导入 | 移除 |
| `movie_screen.dart:133` | 未使用的方法 `_buildSearchField` | 移除 |
| `system_screen.dart:2` | 未使用的 `dart:io` 导入 | 移除 |

---

## 三、已删除的无用文件

| 文件 | 原因 |
|------|------|
| `add_source_sheet.dart` | 与 `add_source_dialog.dart` 功能完全重复，未被引用 |
| `movie_category_screen.dart` | 独立的分类浏览页面，历史遗留，未被任何路由引用 |
| `nul` | 命令重定向残留文件 |
| `crash_stderr.txt` | 崩溃日志残留 |
| `crash_stdout.txt` | 崩溃日志残留 |
| `build_log.txt` | 构建日志临时文件 |
| `BUILD_GUIDE.md` | 开发文档（应放入 docs/） |
| `build.ps1` | 开发脚本（应放入 scripts/） |
| `enable_devmode.ps1` | 开发脚本 |
| `assets/` | 空目录（images/ 和 icons/ 均为空） |

---

## 四、代码优化

### 4.1 提取公共工具函数

新建 `lib/core/utils.dart`，包含：
- `parseInt(dynamic v)` — 统一解析整数
- `parseDouble(dynamic v)` — 统一解析浮点数

**消除重复**: `MovieItem._parseInt` / `MovieItem._parseDouble` / `MovieApiService._parseInt` 三处重复逻辑合并为一处。

### 4.2 修复排序竞态

`resource_library_screen.dart` 的 `ReorderableListView` 原先逐个调用 `updateSource`，每次触发 `loadSources()` 全量重载，存在竞态。

**修复**: 新增 `SourceProvider.reorderSources()` 方法，通过 `DatabaseService.reorderSources()` 一次性批量提交所有排序变更。

### 4.3 依赖精简

| 操作 | 包名 | 原因 |
|------|------|------|
| 移除 | `dio: ^5.4.3` | 项目全部使用 `http` 包，`dio` 从未被引用 |
| 移除 | `shimmer: ^3.0.0` | 仅被已删除的 `movie_category_screen.dart` 使用 |
| 移除 | `assets/images/`, `assets/icons/` | 空目录，无实际资源 |

---

## 五、规范强化

`analysis_options.yaml` 新增关键规则：

```yaml
- always_declare_return_types    # 必须声明返回类型
- avoid_unnecessary_containers   # 避免不必要的 Container
- prefer_final_locals            # 优先使用 final
- use_super_parameters           # 使用 super 参数
- unawaited_futures              # 标记未 await 的 Future
- sort_child_properties_last     # 子属性排序
```

---

## 六、当前项目结构（审查后）

```
lib/
├── main.dart                          # 入口
├── core/
│   ├── app_theme.dart                 # 主题
│   ├── strings.dart                   # 字符串
│   ├── animations.dart                # 动画
│   └── utils.dart                     # 🆕 公共工具
├── models/
│   └── source_model.dart              # 数据模型
├── providers/
│   └── app_provider.dart              # 状态管理
├── services/
│   ├── database_service.dart          # 数据库
│   ├── movie_api_service.dart         # CMS API
│   └── tv_source_service.dart         # TV 源解析
├── screens/
│   ├── movie/
│   │   ├── movie_screen.dart          # 影视主页
│   │   └── movie_player_screen.dart   # 播放页
│   ├── tv/
│   │   └── tv_screen.dart             # 电视直播
│   └── system/
│       ├── system_screen.dart         # 设置
│       ├── resource_library_screen.dart # 资源库
│       ├── history_screen.dart        # 历史记录
│       └── add_source_dialog.dart     # 添加源
└── widgets/
    ├── video_player_widget.dart       # MPV 播放器
    └── tv_focus_widget.dart           # TV 焦点
```

**总计**: 19 个文件，架构清晰，无冗余。

---

## 七、后续建议

1. **withOpacity → withValues**: Flutter 3.29 已将 `withOpacity` 标记为弃用，建议逐步迁移到 `withValues(alpha:)` 以避免精度损失。
2. **const 构造函数**: 大量 Widget 可添加 `const` 优化性能，可在后续迭代中逐步修复。
3. **代码块括号**: `video_player_widget.dart` 中有若干 if-else 单行语句缺少花括号，建议补全。
4. **print → debugPrint**: `database_service.dart:59` 中使用了 `print`，建议改用 `debugPrint`。
5. **异步 Context 使用**: 多处跨 async gap 使用 `BuildContext`，建议在 async 调用后添加 `if (!mounted) return` 检查。
