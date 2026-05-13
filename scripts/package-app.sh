#!/usr/bin/env bash
# 将 Release 构建的可执行文件打成 macOS .app 包，输出到 dist/（或第一个参数指定的目录）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_BASE="${1:-$ROOT/dist}"
APP_NAME="MiddleClickMenu.app"
CONTENTS="$OUT_BASE/$APP_NAME/Contents"

cd "$ROOT"
swift build -c release

BIN="$ROOT/.build/release/MiddleClickMenu"
if [[ ! -x "$BIN" ]]; then
  echo "error: 未找到 Release 可执行文件: $BIN" >&2
  exit 1
fi

rm -rf "$OUT_BASE/$APP_NAME"
mkdir -p "$CONTENTS/MacOS"
cp "$BIN" "$CONTENTS/MacOS/MiddleClickMenu"
cp "$ROOT/Sources/MiddleClickMenu/Resources/Info.plist" "$CONTENTS/Info.plist"
chmod +x "$CONTENTS/MacOS/MiddleClickMenu"

echo "已生成: $OUT_BASE/$APP_NAME"
echo "可将该 .app 拖入「应用程序」文件夹使用。"
