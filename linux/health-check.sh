#!/usr/bin/env bash
#
# health-check.sh — one-screen overview of a Linux server's health
#
# Prints: host info, uptime/load, CPU, memory, disk, top processes,
# failed systemd services, listening ports, and recent logins.
# Read-only — safe to run any time, on any server.
#
# Usage: ./health-check.sh

set -uo pipefail

section() { echo; echo "=== $1 ==="; }

section "Host"
hostnamectl 2>/dev/null | grep -E 'Static hostname|Operating System|Kernel' || hostname
date

section "Uptime & Load"
uptime

section "CPU"
nproc | xargs echo "Cores:"
grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs echo "Model:" || true

section "Memory"
free -h

section "Disk"
df -h -x tmpfs -x devtmpfs -x overlay 2>/dev/null || df -h

section "Top 5 processes by CPU"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6

section "Top 5 processes by Memory"
ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -6

section "Failed services"
if systemctl list-units --failed --no-legend 2>/dev/null | grep -q .; then
  systemctl list-units --failed --no-legend
else
  echo "None"
fi

section "Listening ports"
ss -tulpn 2>/dev/null | head -20 || netstat -tulpn 2>/dev/null | head -20

section "Last 5 logins"
last -n 5 | head -5

echo
echo "Health check done: $(hostname) @ $(date '+%F %T')"
