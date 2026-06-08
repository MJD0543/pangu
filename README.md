<h1 align="center">盘古影视</h1>
<p align="center"><strong>全平台 · 轻量 · 高性能影视播放器</strong></p>
<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20macOS%20%7C%20iOS%20%7C%20Linux-blue" alt="platforms">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="flutter">
  <img src="https://img.shields.io/badge/player-MPV-691C14" alt="mpv">
  <img src="https://img.shields.io/badge/source-closed-red" alt="closed-source">
</p>

---

> ⚠️ **本项目已闭源**。源代码不再公开，仅提供编译后的安装包下载。

---

## ✨ 特性

- **全平台覆盖** — Windows / Android / macOS / iOS / Linux / Android TV，一套代码全端运行
- **MPV 内核** — 基于 media_kit + libmpv，支持 H.265/HEVC、4K、HDR 硬解，媲美专业播放器画质
- **影视源聚合** — 自由添加 Apple CMS / TVBOX 等多格式影视源，支持拼音搜索、智能分页
- **电视直播** — 支持 M3U/TXT 直播源，频道分组管理
- **多源并行搜索** — 三轨并行搜索策略（拼音索引 + 关键字 + 全量兜底），快速精准
- **智能更新** — GitHub Releases 静默检测 + 平台感知下载，一键安装
- **青少年模式** — 密码保护 + 源隐藏
- **简约设计** — 明暗主题自动切换，适配桌面键鼠 + TV 遥控器双交互

---

## 📦 下载

👉 [**最新 Release**](https://github.com/MJD0543/pangu/releases/latest)

| 平台 | 安装包 | 说明 |
|------|--------|------|
| Windows 64 | `PanguInstaller-x64.exe` | 一键安装 |
| Android | `Pangu-vX.Y.Z.apk` | 含 Android TV 支持 |
| Windows 64 免装 | `PanguPortable-vX.Y.Z-x64.7z` | 解压即用 |

---

## 🛠 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 状态管理 | Provider |
| 视频内核 | media_kit + libmpv (硬件解码) |
| 数据存储 | sqflite (SQLite) + SharedPreferences |
| 更新服务 | GitHub Releases API |

---

## 📄 License

Copyright © 2024 盘古影视. All rights reserved.
