// udp.h — 单向 UDP 帧发送，协议与 docs/PROTOCOL.md 完全一致
//
// 悬浮窗（com.sys.deskhelper）已经在 127.0.0.1:29000 上收文本帧：
//   FRAME\n
//   U <nx> <ny> <hp> <mx> 0 <cd> <dist> <oa>\n   （0~N 行）
//   A <nx> <ny> <ang> <vang> <spd>\n           （可选 1 行）
//   END\n
// 进程外 espd 只是换了个生产者，字节格式一字不改 → 悬浮窗零改动。
#ifndef ESPD_UDP_H
#define ESPD_UDP_H

#include <stdint.h>

typedef struct {
    int fd;
    uint16_t port;
} udp_sock;

/* 创建 UDP socket（不 connect，每次 sendto 到 127.0.0.1:port）。成功 0 */
int  udp_open(udp_sock *s, uint16_t port);
void udp_close(udp_sock *s);

/* 发送一整帧（buf 通常以 "FRAME\n" 开头 "END\n" 结尾）。成功返回发出字节数 */
int  udp_send(udp_sock *s, const char *buf, size_t len);

#endif
