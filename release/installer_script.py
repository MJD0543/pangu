# -*- coding: utf-8 -*-
"""
盘古影视 - 自定义安装器（PyInstaller 打包用）
功能：
  1. 解压内嵌的 Release 文件到目标目录
  2. 创建桌面快捷方式
  3. 可选启动应用
支持：Windows 7+
"""
import os
import sys
import zipfile
import shutil
import subprocess
import ctypes
from pathlib import Path

# ---------- 工具函数 ----------
def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def run_as_admin():
    """重新以管理员权限启动自己"""
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, " ".join(sys.argv), None, 1
    )
    sys.exit(0)

def get_resource_path(rel_path):
    """获取打包后资源文件的真实路径"""
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, rel_path)
    return os.path.join(os.path.abspath("."), rel_path)

# ---------- Tkinter GUI ----------
import tkinter as tk
from tkinter import filedialog, messagebox

class InstallerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("盘古影视 - 安装向导")
        self.root.geometry("520x380")
        self.root.resizable(False, False)
        self.root.configure(bg="#1A1A1F" if self._is_dark_os() else "#F5F5FA")

        # 目标安装目录
        self.install_dir = tk.StringVar(value=self._default_install_dir())

        self._build_ui()

    def _is_dark_os(self):
        try:
            import winreg
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                                   r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")
            val, _ = winreg.QueryValueEx(key, "AppsUseLightTheme")
            return val == 0
        except Exception:
            return False

    def _default_install_dir(self):
        pf = os.environ.get("ProgramFiles", "C:\\Program Files")
        return os.path.join(pf, "盘古影视")

    def _build_ui(self):
        root = self.root
        bg = root["bg"]

        # 标题
        tk.Label(root, text="盘古影视", font=("Microsoft YaHei", 18, "bold"),
                  bg=bg, fg="#00C9A7" if bg == "#1A1A1F" else "#00A88X").pack(pady=(28, 6))
        tk.Label(root, text="跨平台影视播放器", font=("Microsoft YaHei", 10),
                  bg=bg, fg="#888888").pack()

        tk.Frame(root, height=1, bg="#333333" if bg == "#1A1A1F" else "#DDDDDD").pack(fill="x", padx=40, pady=18)

        # 安装路径
        frm = tk.Frame(root, bg=bg)
        frm.pack(fill="x", padx=40)
        tk.Label(frm, text="安装目录：", font=("Microsoft YaHei", 9), bg=bg,
                  fg="#CCCCCC" if bg == "#1A1A1F" else "#333333").pack(side="left")
        tk.Entry(frm, textvariable=self.install_dir, width=38,
                  font=("Microsoft YaHei", 9)).pack(side="left", padx=(4, 6))
        tk.Button(frm, t="浏览...", command=self._browse,
                   font=("Microsoft YaHei", 9), cursor="hand2",
                   bg="#333333" if bg == "#1A1A1F" else "#EEEEEE",
                   fg="#CCCCCC" if bg == "#1A1A1F" else "#333333",
                   activebackground="#00C9A7", relief="flat", padx=8).pack(side="left")

        tk.Frame(root, height=1, bg="#333333" if bg == "#1A1A1F" else "#DDDDDD").pack(fill="x", padx=40, pady=18)

        # 进度条（初始隐藏）
        self.progress_var = tk.DoubleVar()
        self.progress_bar = tk.ttk.Progressbar(root, variable=self.progress_var, maximum=100, length=440)
        # 进度文字
        self.progress_label = tk.Label(root, text="", font=("Microsoft YaHei", 9), bg=bg, fg="#888888")

        # 按钮区
        btn_frm = tk.Frame(root, bg=bg)
        btn_frm.pack(side="bottom", fill="x", padx=40, pady=18)

        self.btn_install = tk.Button(btn_frm, text="安装", command=self._start_install,
                                     bg="#00C9A7", fg="white", font=("Microsoft YaHei", 10, "bold"),
                                     cursor="hand2", relief="flat", padx=32, pady=6)
        self.btn_install.pack(side="right")

        tk.Button(btn_frm, text="取消", command=root.destroy,
                   font=("Microsoft YaHei", 10), cursor="hand2",
                   bg="#333333" if bg == "#1A1A1F" else "#EEEEEE",
                   fg="#CCCCCC" if bg == "#1A1A1F" else "#333333",
                   relief="flat", padx=24, pady=6).pack(side="right", padx=8)

        self.status_label = tk.Label(root, text="准备安装...", font=("Microsoft YaHei", 9), bg=bg, fg="#888888")
        self.status_label.pack(side="bottom", pady=(0, 8))

    def _browse(self):
        d = filedialog.askdirectory(initialdir=self.install_dir.get())
        if d:
            self.install_dir.set(d)

    def _set_progress(self, pct, text):
        self.progress_var.set(pct)
        self.progress_label.config(text=text)
        self.root.update_idletasks()

    def _start_install(self):
        self.btn_install.config(state="disabled")
        self.progress_bar.pack(pady=(0, 4))
        self.progress_label.pack()
        self.root.after(100, self._do_install)

    def _do_install(self):
        dest = self.install_dir.get()
        try:
            os.makedirs(dest, exist_ok=True)
        except PermissionError:
            messagebox.showerror("权限不足", "无法写入目标目录，请尝试以管理员身份运行安装器。")
            self.btn_install.config(state="normal")
            return

        # 查找内嵌的 package.zip（打包后位于 sys._MEIPASS）
        zip_path = get_resource_path("package.zip")
        if not os.path.isfile(zip_path):
            # 开发模式：找 build 目录
            zip_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                   "..", "release", "package.zip")
            zip_path = os.path.abspath(zip_path)
        if not os.path.isfile(zip_path):
            messagebox.showerror("错误", f"找不到安装包文件：\n{zip_path}")
            self.btn_install.config(state="normal")
            return

        try:
            total = 0
            with zipfile.ZipFile(zip_path, "r") as zf:
                total = len(zf.namelist())
                extracted = 0
                for member in zf.namelist():
                    zf.extract(member, dest)
                    extracted += 1
                    if extracted % 10 == 0:
                        pct = int(extracted / total * 100)
                        self._set_progress(pct, f"解压中... ({extracted}/{total})")
                self._set_progress(100, "解压完成")

            # 创建桌面快捷方式
            self.status_label.config(text="创建快捷方式...")
            self._create_shortcut(dest)
            self._set_progress(100, "安装完成！")

            # 询问是否启动
            if messagebox.askyesno("安装完成", "盘古影视已安装成功！\n\n是否立即启动？"):
                exe = os.path.join(dest, "盘古影视.exe")
                if os.path.isfile(exe):
                    subprocess.Popen(exe, cwd=dest)
        except Exception as e:
            messagebox.showerror("安装失败", str(e))
        finally:
            self.btn_install.config(state="normal")

    def _create_shortcut(self, install_dir):
        try:
            import pythoncom
            from win32com.client import Dispatch
            desktop = os.path.join(os.environ["USERPROFILE"], "Desktop")
            shortcut_path = os.path.join(desktop, "盘古影视.lnk")
            shell = Dispatch("WScript.Shell")
            shortcut = shell.CreateShortcut(shortcut_path)
            shortcut.Targetpath = os.path.join(install_dir, "盘古影视.exe")
            shortcut.WorkingDirectory = install_dir
            shortcut.IconLocation = os.path.join(install_dir, "盘古影视.exe")
            shortcut.save()
        except ImportError:
            # 无 pywin32 时用简单方式
            try:
                import winshell
                from win32com.client import Dispatch
                desktop = winshell.desktop()
                shortcut_path = os.path.join(desktop, "盘古影视.lnk")
                shell = Dispatch("WScript.Shell")
                shortcut = shell.CreateShortcut(shortcut_path)
                shortcut.Targetpath = os.path.join(install_dir, "盘古影视.exe")
                shortcut.WorkingDirectory = install_dir
                shortcut.save()
            except ImportError:
                pass  # 跳过快捷方式创建

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    if not is_admin():
        # 请求 UAC 提权（可选，安装到 Program Files 需要）
        # run_as_admin()
        # 不强制提权，让用户选择安装目录
        pass
    app = InstallerGUI()
    app.run()
