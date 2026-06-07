#!/usr/bin/env python3
"""上传 Asset 到 GitHub Release"""

import requests
import os

TOKEN = os.environ.get("GITHUB_TOKEN", "")
if not TOKEN:
    print("请设置 GITHUB_TOKEN 环境变量")
    print("示例: set GITHUB_TOKEN=ghp_xxx && python upload_assets.py")
    exit(1)
REPO = "MJD0543/pangu"
RELEASE_ID = 335539785

def upload_asset(file_path, upload_name):
    """上传文件到 GitHub Release"""
    base_url = f"https://uploads.github.com/repos/{REPO}/releases/{RELEASE_ID}/assets"
    
    print(f"正在上传: {upload_name}")
    
    headers = {
        "Authorization": f"token {TOKEN}",
        "Content-Type": "application/octet-stream",
    }
    
    with open(file_path, "rb") as f:
        data = f.read()
    
    file_size_mb = len(data) / (1024 * 1024)
    print(f"  文件大小: {file_size_mb:.1f} MB")
    
    response = requests.post(
        base_url,
        params={"name": upload_name},
        headers=headers,
        data=data,
        timeout=600,
        verify=False
    )
    
    if response.status_code == 201:
        result = response.json()
        print(f"  ✅ 上传成功! 名称: {result['name']}, ID: {result['id']}")
        return True
    else:
        print(f"  ❌ 上传失败: {response.status_code} - {response.text[:200]}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("上传 盘古影视 安装器到 GitHub Release v1.0.0")
    print("=" * 60)
    
    assets = [
        (r"E:\pangu\release\盘古影视安装器_32位.exe", "PanguInstaller-x86.exe"),
        (r"E:\pangu\release\盘古影视安装器_64位.exe", "PanguInstaller-x64.exe"),
    ]
    
    results = []
    for file_path, upload_name in assets:
        results.append(upload_asset(file_path, upload_name))
        print()
    
    print("=" * 60)
    success = all(results)
    print(f"上传结果: {'全部成功!' if success else '部分失败'}")
    if success:
        print("查看 Release: https://github.com/MJD0543/pangu/releases/tag/v1.0.0")
