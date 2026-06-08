#!/bin/bash
# ============================================================
# 盘古影视 — 多平台编译验证脚本
# 用法: bash scripts/verify_all.sh
#
# 在 Windows 上验证所有可编译的平台（跳过 macOS/iOS）
# 不生成 release 包，仅验证能否编译通过
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

# 自动检测 flutter 路径
FLUTTER="flutter"
if [ -f "/c/Program Files/flutter/bin/flutter.bat" ]; then
  FLUTTER="/c/Program Files/flutter/bin/flutter.bat"
elif [ -f "/c/Program Files/flutter/bin/flutter" ]; then
  FLUTTER="/c/Program Files/flutter/bin/flutter"
fi

echo ""
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo -e "${YELLOW}  盘古影视 — 多平台编译验证${NC}"
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo ""

run_check() {
  local platform=$1
  local cmd=$2
  echo -e "${YELLOW}[→] 验证 $platform ...${NC}"
  if eval "$cmd" 2>&1 | tail -3; then
    echo -e "${GREEN}[✓] $platform 编译通过${NC}"
    ((PASS++))
  else
    echo -e "${RED}[✗] $platform 编译失败${NC}"
    ((FAIL++))
  fi
  echo ""
}

cd "$(dirname "$0")/.."

# ── 静态分析（快速，必须过） ──
echo -e "${YELLOW}[→] 静态分析 (flutter analyze) ...${NC}"
if $FLUTTER analyze --no-pub 2>&1 | tail -5; then
  echo -e "${GREEN}[✓] 静态分析通过${NC}"
  ((PASS++))
else
  echo -e "${RED}[✗] 静态分析发现问题${NC}"
  ((FAIL++))
fi
echo ""

# ── Windows ──
run_check "Windows" "$FLUTTER build windows --debug"

# ── Linux (WSL) ──
if grep -qi microsoft /proc/version 2>/dev/null; then
  run_check "Linux" "$FLUTTER build linux --debug"
else
  echo -e "${YELLOW}[○] Linux — 跳过（需要 WSL）${NC}"
  ((SKIP++))
  echo ""
fi

# ── Android ──
if [ -d "/c/Program Files/Android" ] || [ -d "$HOME/Android" ]; then
  run_check "Android" "$FLUTTER build apk --debug"
else
  echo -e "${YELLOW}[○] Android — 跳过（未检测到 Android SDK）${NC}"
  ((SKIP++))
  echo ""
fi

# ── macOS / iOS ──
echo -e "${YELLOW}[○] macOS — 跳过（需要 macOS 设备）${NC}"
echo -e "${YELLOW}[○] iOS   — 跳过（需要 macOS 设备）${NC}"
((SKIP+=2))
echo ""

# ── 结果汇总 ──
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo -e "  通过: ${GREEN}$PASS${NC}  |  失败: ${RED}$FAIL${NC}  |  跳过: ${YELLOW}$SKIP${NC}"
echo -e "${YELLOW}════════════════════════════════════════${NC}"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
