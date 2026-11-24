#!/system/bin/sh
# 97_esp_watch.sh — 兼容入口：只负责拉起模块里的 espd 启动器
#
# 守护逻辑只有一份：/data/adb/modules/esp_local/service.d/97_espd.sh
# （进程外只读 espd，无 zygote / gadget / post-fs-data 依赖）。
# 只在「管理器不跑模块 service.d、只跑全局 /data/adb/service.d」时才需要这个文件。

MOD=/data/adb/modules/esp_local
if [ -f "$MOD/service.d/97_espd.sh" ]; then
  nohup sh "$MOD/service.d/97_espd.sh" >/dev/null 2>&1 &
fi
