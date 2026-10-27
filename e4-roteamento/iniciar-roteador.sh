#!/bin/sh
# Roda em r1, r2 e r3. A variável ROLE diz qual é.
ip route del default 2>/dev/null || true
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true

mkdir -p /run/bird && exec bird -f -c "/lab/bird-$ROLE.conf"