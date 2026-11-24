#!/system/bin/sh
# 97_espd.sh — 唯一开机入口（KernelSU/Magisk/APatch 的 service.d 都会执行本文件）
#
# 实际逻辑只有一句：把 supervisor 丢到后台，自身立刻返回，不阻塞 init。
# supervisor 全程运行在 u:r:ksu:s0（实测可读任意 app 内存），不需要 su、不需要 post-fs-data。

MOD=/data/adb/modules/esp_local
[ -d "$MOD" ] || MOD=$(cd "${0%/*}/.." 2>/dev/null && pwd)

BIN=$MOD/bin/espd-arm64
SUP=$MOD/bin/espd-supervisor.sh
DIR=/data/local/tmp/.esp

[ -x "$BIN" ] || exit 0
[ -f "$SUP" ] || exit 0

mkdir -p "$DIR" 2>/dev/null

# 单例：espd 或 supervisor 任一在跑就不再拉起
if [ -n "$(pidof espd-arm64)" ]; then exit 0; fi
if pidof -x espd-supervisor.sh >/dev/null 2>&1; then exit 0; fi

nohup sh "$SUP" "$MOD" >/dev/null 2>&1 &
exit 0
