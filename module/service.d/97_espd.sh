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

# 单例只看 supervisor（PID 文件 + /proc cmdline 校验）。
# 不能顺便用 `pidof espd-arm64` 提前退出：espd 常驻，而 supervisor 可能被
# kill -9 过，只判 espd 存活会导致「daemon 在、没人管 desk-watch」永久卡死。
# supervisor 自己会识别已有的 daemon，只做监控，不会抢锁重启。
# 也不能用 pidof -x espd-supervisor.sh —— 脚本以 "sh 脚本" 方式运行，
# 进程名是 sh，按 comm 永远匹配不到。
SUPP=$(cat "$DIR/supervisor.pid" 2>/dev/null | tr -d ' \n')
if [ -n "$SUPP" ] && [ -d "/proc/$SUPP" ]; then
  c=$(tr '\0' ' ' < "/proc/$SUPP/cmdline" 2>/dev/null)
  case "$c" in *espd-supervisor.sh*) exit 0;; esac
fi

if command -v setsid >/dev/null 2>&1; then
  setsid sh "$SUP" "$MOD" </dev/null >/dev/null 2>&1 &
else
  nohup sh "$SUP" "$MOD" </dev/null >/dev/null 2>&1 &
fi
exit 0
