#!/usr/bin/env sh
setpci -v -s '*:*' latency_timer=20 2>/dev/null || true
setpci -v -s '0:0' latency_timer=0 2>/dev/null || true
setpci -v -s '0:2' latency_timer=0 2>/dev/null || true
setpci -v -d "*:*:04xx" latency_timer=80 2>/dev/null || true
echo "PCI latency timers configured"
