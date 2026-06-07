#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
盘古影视 - 自定义安装器
内嵌应用数据，提供图形化安装界面，支持卸载
"""

import os
import sys
import zipfile
import shutil
import threading
import subprocess
import ctypes
import struct
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


# ==================== 注册表操作（ctypes，无额外依赖） ====================

advapi32 = ctypes.windll.advapi32

# 注册表常量
HKEY_LOCAL_MACHINE = 0x80000002
KEY_WRITE = 0x20006
KEY_WOW64_64KEY = 0x0100
KEY_WOW64_32KEY = 0x0200
REG_SZ = 1
REG_DWORD = 4

def reg_create_key(hkey, subkey, sam_desired):
    """创建或打开注册表键，返回句柄"""
    hkey_out = ctypes.c_void_p()
    disposition = ctypes.c_ulong()
    result = advapi32.RegCreateKeyExW(
        ctypes.c_void_p(hkey),
        ctypes.c_wchar_p(subkey),
        0,
        None,
        0,
        sam_desired,
        None,
        ctypes.byref(hkey_out),
        ctypes.byref(disposition)
    )
    if result == 0:
        return hkey_out.value
    return None

def reg_set_value(hkey, value_name, data):
    """设置注册表字符串值"""
    if isinstance(data, str):
        data = data + '\x00'
        buf = (ctypes.c_wchar * len(data))()
        for i, c in enumerate(data):
            buf[i] = c
        advapi32.RegSetValueExW(
            hkey,
            ctypes.c_wchar_p(value_name),
            0,
            REG_SZ,
            ctypes.byref(buf),
            len(data) * 2
        )

def reg_set_dword(hkey, value_name, value):
    """设置注册表 DWORD 值"""
    advapi32.RegSetValueExW(
        hkey,
        ctypes.c_wchar_p(value_name),
        0,
        REG_DWORD,
        ctypes.byref(ctypes.c_ulong(value)),
        4
    )

def reg_close_key(hkey):
    advapi32.RegCloseKey(hkey)


def write_uninstall_registry(install_path, uninstall_cmd):
    """向 HKLM 写入卸载信息，让程序出现在'应用和功能'中"""
    app_name = "盘古影视"
    # 尝试 64 位视图
    hkey = reg_create_key(
        HKEY_LOCAL_MACHINE,
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%s" % app_name,
        KEY_WRITE | KEY_WOW64_64KEY
    )
    if hkey is None:
        # 尝试 32 位视图
        hkey = reg_create_key(
            HKEY_LOCAL_MACHINE,
            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\%s" % app_name,
            KEY_WRITE | KEY_WOW64_32KEY
        )
    if hkey is None:
        # 降级到 HKCU（当前用户，不需要管理员权限）
        hkey = reg_create_key(
            0x80000001,  # HKEY_CURRENT_USER
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%s" % app_name,
            KEY_WRITE
        )
    if hkey is None:
        return False

    try:
        reg_set_value(hkey, "DisplayName", app_name)
        reg_set_value(hkey, "DisplayVersion", "1.0.0")
        reg_set_value(hkey, "Publisher", "盘古影视")
        reg_set_value(hkey, "InstallLocation", install_path)
        reg_set_value(hkey, "UninstallString", uninstall_cmd)
        reg_set_value(hkey, "QuietUninstallString", uninstall_cmd)
        reg_set_dword(hkey, "NoModify", 1)
        reg_set_dword(hkey, "NoRepair", 1)
        return True
    finally:
        reg_close_key(hkey)


# ==================== 工具函数 ====================

def resource_path(relative_path):
    """获取资源绝对路径，兼容开发环境和 PyInstaller"""
    if hasattr(sys, '_MEIPASS'):
        base = sys._MEIPASS
    else:
        base = os.path.abspath(".")
    return os.path.join(base, relative_path)


def create_windows_shortcut(target_exe, shortcut_path, work_dir):
    """创建 Windows 桌面快捷方式（PowerShell 实现）"""
    ps_cmd = (
        f'$WshShell = New-Object -ComObject WScript.Shell;'
        f'$Shortcut = $WshShell.CreateShortcut("{shortcut_path}");'
        f'$Shortcut.TargetPath = "{target_exe}";'
        f'$Shortcut.WorkingDirectory = "{work_dir}";'
        f'$Shortcut.IconLocation = "{target_exe}";'
        f'$Shortcut.Save()'
    )
    result = subprocess.run(
        ['powershell', '-NoProfile', '-Command', ps_cmd],
        capture_output=True, text=True
    )
    return result.returncode == 0


def create_uninstall_bat(install_path):
    """在安装目录生成 uninstall.bat 卸载脚本"""
    bat_path = os.path.join(install_path, "uninstall.bat")
    exe_name = "盘古影视.exe"
    content = f'''@echo off
chcp 65001 >nul
echo 正在卸载 {exe_name}...
echo.

:: 结束运行中的进程
taskkill /f /im "{exe_name}" >nul 2>&1

:: 删除桌面快捷方式
set "DESKTOP=%USERPROFILE%\\Desktop"
if exist "%DESKTOP%\\盘古影视.lnk" del /f /q "%DESKTOP%\\盘古影视.lnk" >nul 2>&1

:: 删除开始菜单项（如果有）
set "STARTMENU=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs"
if exist "%STARTMENU%\\盘古影视" rmdir /s /q "%STARTMENU%\\盘古影视" >nul 2>&1

:: 删除安装目录
echo 正在删除文件...
cd /d "%TEMP%" 2>nul
rmdir /s /q "{install_path}" 2>nul

:: 删除注册表项（尝试所有位置）
reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\盘古影视" /f >nul 2>&1
reg delete "HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\盘古影视" /f >nul 2>&1
reg delete "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\盘古影视" /f >nul 2>&1

echo.
echo 卸载完成！
pause
'''
    # 写入 UTF-8 with BOM 以便支持中文
    with open(bat_path, 'w', encoding='utf-8-sig') as f:
        f.write(content)
    return bat_path


# ==================== 安装器主类 ====================

class InstallerApp:
    APP_NAME = "盘古影视"
    APP_EXE = "盘古影视.exe"
    DATA_ZIP = "app_data.zip"
    DESKTOP_SHORTCUT = "盘古影视.lnk"

    def __init__(self, root):
        self.root = root
        self.root.title(f"{self.APP_NAME} - 安装向导")
        self.root.geometry("520x440")
        self.root.resizable(False, False)
        self.root.configure(bg='#1a1a2e')

        # 设置窗口图标
        try:
            icon_path = resource_path("app_icon.ico")
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except Exception:
            pass

        # 安装路径
        self.install_path = tk.StringVar(value=self._default_install_path())
        self.is_installing = False

        self._build_ui()
        self._center_window()

    def _default_install_path(self):
        pf = os.environ.get('ProgramFiles', r'C:\Program Files')
        return os.path.join(pf, self.APP_NAME)

    def _center_window(self):
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        if w <= 1:
            w = 520
        if h <= 1:
            h = 440
        x = (self.root.winfo_screenwidth() // 2) - (w // 2)
        y = (self.root.winfo_screenheight() // 2) - (h // 2)
        self.root.geometry(f'{w}x{h}+{x}+{y}')

    # ==================== UI ====================

    def _build_ui(self):
        f = tk.Frame(self.root, bg='#1a1a2e', padx=30, pady=20)
        f.pack(fill='both', expand=True)

        # 标题
        tk.Label(f, text=f"{self.APP_NAME} 安装向导",
                 font=('Microsoft YaHei', 18, 'bold'),
                 bg='#1a1a2e', fg='#e94560').pack(pady=(0, 8))

        tk.Label(f, text="跨平台影视应用 - 发现精彩影视内容",
                 font=('Microsoft YaHei', 10),
                 bg='#1a1a2e', fg='#a0a0a0').pack(pady=(0, 24))

        # 安装路径
        tk.Label(f, text="安装路径：", font=('Microsoft YaHei', 10),
                 bg='#1a1a2e', fg='#ffffff').pack(anchor='w', pady=(0, 4))

        pf = tk.Frame(f, bg='#1a1a2e')
        pf.pack(fill='x')
        self.path_entry = tk.Entry(pf, textvariable=self.install_path,
                                   font=('Microsoft YaHei', 9),
                                   bg='#16213e', fg='#ffffff',
                                   insertbackground='#ffffff',
                                   relief='flat', bd=5)
        self.path_entry.pack(side='left', fill='x', expand=True, padx=(0, 10))

        tk.Button(pf, text="浏览...", font=('Microsoft YaHei', 9),
                  bg='#0f3460', fg='#ffffff', relief='flat',
                  padx=15, pady=5, cursor='hand2',
                  command=self._browse_path).pack(side='right')

        # 进度
        tk.Frame(f, bg='#1a1a2e').pack(fill='x', pady=(16, 0))
        self.status_label = tk.Label(f, text="点击安装即可开始",
                                     font=('Microsoft YaHei', 9),
                                     bg='#1a1a2e', fg='#a0a0a0')
        self.status_label.pack(anchor='w', pady=(4, 2))

        self.progress = ttk.Progressbar(f, mode='determinate', length=460)
        self.progress.pack(fill='x')
        self.progress.pack_forget()

        # 按钮
        bf = tk.Frame(f, bg='#1a1a2e')
        bf.pack(side='bottom', fill='x', pady=(20, 0))

        self.install_btn = tk.Button(bf, text="安装",
                                     font=('Microsoft YaHei', 11, 'bold'),
                                     bg='#e94560', fg='#ffffff',
                                     activebackground='#ff6b81',
                                     relief='flat', padx=40, pady=10,
                                     cursor='hand2',
                                     command=self._start_install)
        self.install_btn.pack(side='right', padx=(10, 0))

        tk.Button(bf, text="取消", font=('Microsoft YaHei', 11),
                  bg='#0f3460', fg='#ffffff', relief='flat',
                  padx=40, pady=10, cursor='hand2',
                  command=self.root.quit).pack(side='right')

    def _browse_path(self):
        path = filedialog.askdirectory(title="选择安装路径")
        if path:
            self.install_path.set(path)

    # ==================== 安装流程 ====================

    def _start_install(self):
        if self.is_installing:
            return
        target = self.install_path.get()
        if not target:
            messagebox.showerror("错误", "请选择安装路径")
            return

        # 写权限测试
        try:
            os.makedirs(target, exist_ok=True)
            probe = os.path.join(target, '.w_test')
            open(probe, 'w').close()
            os.remove(probe)
        except Exception:
            messagebox.showerror("错误", "安装路径无写入权限，请更换目录")
            return

        self.is_installing = True
        self.install_btn.config(state='disabled', text="安装中...")
        self.progress.pack(fill='x')
        self.progress['value'] = 0
        self.status_label.config(text="正在准备安装...")

        threading.Thread(target=self._install, daemon=True).start()

    def _install(self):
        try:
            target = self.install_path.get()

            # 1. 查找并解压数据
            self._set_status("正在解压文件...", 0)
            zip_path = resource_path(self.DATA_ZIP)
            if not os.path.exists(zip_path):
                self._show_error(f"找不到内置数据包: {self.DATA_ZIP}")
                return

            with zipfile.ZipFile(zip_path, 'r') as zf:
                names = zf.namelist()
                total = len(names)
                for i, name in enumerate(names):
                    zf.extract(name, target)
                    pct = int((i + 1) / total * 50)
                    self._set_status(f"正在解压... ({i + 1}/{total})", pct)

            # 2. 创建卸载脚本
            self._set_status("正在生成卸载脚本...", 55)
            uninstall_bat = create_uninstall_bat(target)
            uninstall_cmd = f'cmd /c "{uninstall_bat}"'

            # 3. 写入注册表（卸载信息）
            self._set_status("正在注册卸载信息...", 65)
            write_uninstall_registry(target, uninstall_cmd)

            # 4. 创建桌面快捷方式
            self._set_status("正在创建桌面快捷方式...", 75)
            self._make_shortcut(target)

            # 5. 完成
            self._set_status("安装完成!", 100)
            self.root.after(0, self._on_success)

        except Exception as e:
            self._show_error(str(e))

    def _set_status(self, msg, pct):
        self.root.after(0, lambda: self.status_label.config(text=msg))
        self.root.after(0, lambda: self.progress.configure(value=pct))

    def _make_shortcut(self, target):
        exe_path = os.path.join(target, self.APP_EXE)
        if not os.path.exists(exe_path):
            # 尝试查找任意 exe
            for fn in os.listdir(target):
                if fn.lower().endswith('.exe'):
                    exe_path = os.path.join(target, fn)
                    break
        if not os.path.exists(exe_path):
            self._set_status("(未找到可执行文件，跳过快捷方式)", 80)
            return

        desktop = os.path.join(os.path.expanduser('~'), 'Desktop')
        lnk_path = os.path.join(desktop, self.DESKTOP_SHORTCUT)

        if create_windows_shortcut(exe_path, lnk_path, target):
            self._set_status("桌面快捷方式已创建", 80)
        else:
            self._set_status("(快捷方式创建失败)", 80)

    # ==================== 结果 ====================

    def _on_success(self):
        self.progress.pack_forget()
        self.status_label.config(text="安装完成！", fg='#00ff00')
        self.install_btn.config(text="完成", state='normal', command=self.root.quit)
        self.is_installing = False

        if messagebox.askyesno("安装完成",
                               f"{self.APP_NAME} 已成功安装。\n\n是否立即运行？"):
            self._launch()

    def _show_error(self, msg):
        def cb():
            self.progress.pack_forget()
            self.status_label.config(text=f"安装失败：{msg}", fg='#ff0000')
            self.install_btn.config(text="重试", state='normal',
                                    command=self._start_install)
            self.is_installing = False
        self.root.after(0, cb)

    def _launch(self):
        exe_path = os.path.join(self.install_path.get(), self.APP_EXE)
        if not os.path.exists(exe_path):
            for fn in os.listdir(self.install_path.get()):
                if fn.lower().endswith('.exe'):
                    exe_path = os.path.join(self.install_path.get(), fn)
                    break
        if os.path.exists(exe_path):
            subprocess.Popen(exe_path)
            self.root.quit()
        else:
            messagebox.showerror("错误", "找不到应用程序")


# ==================== 入口 ====================

def main():
    root = tk.Tk()
    InstallerApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
