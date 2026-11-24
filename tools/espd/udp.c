// udp.c — 见 udp.h
#define _GNU_SOURCE
#include "udp.h"

#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>

int udp_open(udp_sock *s, uint16_t port) {
    memset(s, 0, sizeof *s);
    s->fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (s->fd < 0) return -1;
    s->port = port;
    return 0;
}

void udp_close(udp_sock *s) {
    if (s->fd >= 0) { close(s->fd); s->fd = -1; }
}

int udp_send(udp_sock *s, const char *buf, size_t len) {
    if (s->fd < 0 || !buf || len == 0) return -1;
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof sa);
    sa.sin_family = AF_INET;
    sa.sin_port = htons(s->port);
    sa.sin_addr.s_addr = htonl(INADDR_LOOPBACK);   /* 127.0.0.1 */
    ssize_t n = sendto(s->fd, buf, len, 0, (struct sockaddr *)&sa, sizeof sa);
    return (int)n;
}

