#!/bin/bash
set -uo pipefail

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
skip()  { echo -e "  ${YELLOW}⏭  SKIP${NC} $1 (already applied)"; }
warn()  { echo -e "  ${RED}⚠${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
header(){ echo ""; echo -e "${BOLD}${GREEN}=== $1 ===${NC}"; }

NEED_REBOOT=0
NEED_REINITRAMFS=0
NEED_GRUB=0

# ---------- Root check ----------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run with sudo/root.${NC}"
    exit 1
fi

# Detect physical disks dynamically (NVMe, SATA SSDs, HDDs, etc.)
PHYSICAL_DEVS=$(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' || true)
PHYSICAL_DEVS=${PHYSICAL_DEVS:-nvme0n1}

# ==================================================================
# ROLLBACK MODE
# ==================================================================
rollback() {
    header "ROLLING BACK ALL OPTIMIZATIONS"

    for f in \
        /etc/sysctl.d/70-performance-tuning.conf \
        /etc/systemd/zram-generator.conf \
        /etc/udev/rules.d/60-ioschedulers.rules \
        /etc/tmpfiles.d/thp.conf \
        /etc/modprobe.d/disable-watchdog.conf \
        /usr/bin/pci-latency \
        /etc/systemd/system/pci-latency.service \
        /etc/systemd/system/network-qdisc.service \
        /etc/udev/rules.d/99-cpu-dma-latency.rules
    do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            ok "Removed $f"
        else
            skip "$f (not present)"
        fi
    done

    systemctl disable --now pci-latency.service 2>/dev/null || true
    systemctl disable --now network-qdisc.service 2>/dev/null || true
    systemctl stop systemd-zram-setup@zram0 2>/dev/null || true

    if grep -q "nowatchdog" /etc/default/grub 2>/dev/null; then
        sed -i -E 's/\bnowatchdog[[:space:]]*//' /etc/default/grub
        ok "Removed nowatchdog from GRUB_CMDLINE_LINUX_DEFAULT"
        NEED_GRUB=1
    fi

    # Restore default kernel parameters from remaining sysctl configurations
    sysctl --system 2>/dev/null || true

    systemctl daemon-reload
    udevadm control --reload 2>/dev/null || true

    if [[ $NEED_GRUB -eq 1 ]]; then
        if command -v grub-mkconfig &>/dev/null; then
            grub-mkconfig -o /boot/grub/grub.cfg
            ok "Regenerated grub.cfg"
        else
            warn "grub-mkconfig not found — regenerate your bootloader config manually"
        fi
    fi

    if command -v mkinitcpio &>/dev/null; then
        mkinitcpio -P
        ok "Regenerated initramfs"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}Rollback complete. Reboot to fully restore vanilla state:${NC} sudo reboot"
    exit 0
}

# ==================================================================
# VERIFY MODE (same as before, standalone)
# ==================================================================
verify() {
    header "OPTIMIZATION VERIFICATION"

    echo -e "${BOLD}${CYAN}Kernel Version:${NC}"
    echo -e "  Running kernel: ${YELLOW}$(uname -r)${NC}"

    echo ""
    echo -e "${BOLD}${CYAN}SYSCTL Settings:${NC}"
    echo -e "  vm.swappiness: ${YELLOW}$(sysctl -n vm.swappiness)${NC}"
    echo -e "  kernel.nmi_watchdog: ${YELLOW}$(sysctl -n kernel.nmi_watchdog)${NC}"
    echo -e "  vm.vfs_cache_pressure: ${YELLOW}$(sysctl -n vm.vfs_cache_pressure)${NC}"

    echo ""
    echo -e "${BOLD}${CYAN}ZRAM Status:${NC}"
    zram_out=$(grep zram /proc/swaps || true)
    [[ -n "$zram_out" ]] && echo -e "  ${YELLOW}${zram_out}${NC}" || warn "No ZRAM device active"

    echo ""
    echo -e "${BOLD}${CYAN}I/O Schedulers:${NC}"
    for dev in $PHYSICAL_DEVS; do
        sched_path="/sys/block/${dev}/queue/scheduler"
        if [[ -f "$sched_path" ]]; then
            echo -e "  ${dev}: ${YELLOW}$(cat "$sched_path")${NC}"
        else
            warn "${dev} not found"
        fi
    done

    echo ""
    echo -e "${BOLD}${CYAN}Watchdog Status:${NC}"
    watchdog_out=$(lsmod | grep -E "sp5100|iTCO|wdat" || true)
    [[ -n "$watchdog_out" ]] && echo -e "  ${YELLOW}${watchdog_out}${NC}" || ok "Watchdogs disabled"

    echo ""
    echo -e "${BOLD}${CYAN}Transparent Hugepages:${NC}"
    if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        echo -e "  ${YELLOW}$(cat /sys/kernel/mm/transparent_hugepage/defrag)${NC}"
    else
        warn "Not available"
    fi

    echo ""
    echo -e "${BOLD}${CYAN}PCI Latency Service:${NC}"
    pci_status=$(systemctl is-active pci-latency.service 2>/dev/null || echo "inactive")
    [[ "$pci_status" == "active" ]] && ok "$pci_status" || warn "$pci_status"

    echo ""
    echo -e "${BOLD}${CYAN}Network Qdisc Service:${NC}"
    net_status=$(systemctl is-active network-qdisc.service 2>/dev/null || echo "inactive")
    [[ "$net_status" == "active" ]] && ok "$net_status" || warn "$net_status"

    echo ""
    echo -e "${BOLD}${GREEN}=========================================${NC}"
    exit 0
}

# ==================================================================
# Arg parsing
# ==================================================================
case "${1:-}" in
    --rollback) rollback ;;
    --verify)   verify ;;
esac

# ==================================================================
# APPLY MODE (idempotent — each step checks before acting)
# ==================================================================

header "PRE-FLIGHT SYSTEM CHECK"
info "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
info "RAM: $(free -h | awk '/^Mem:/{print $2}')"
info "Storage: $(lsblk -dno NAME,SIZE,TYPE | grep -v loop)"
info "Physical disks detected: $(echo $PHYSICAL_DEVS | tr '\n' ' ')"

# --- STEP 1: Sysctl ---
header "STEP 1: Sysctl Optimizations"
SYSCTL_CONF="/etc/sysctl.d/70-performance-tuning.conf"
if [[ -f "$SYSCTL_CONF" ]]; then
    skip "$SYSCTL_CONF"
else
    cat > "$SYSCTL_CONF" << 'EOF'
# ============================================================================
# VIRTUAL MEMORY & SWAPPING
# ============================================================================
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.page-cluster = 0
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 67108864
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000

# ============================================================================
# CPU & INTERRUPT MANAGEMENT
# ============================================================================
kernel.nmi_watchdog = 0
kernel.sched_migration_cost_ns = 5000000
kernel.unprivileged_userns_clone = 1
kernel.printk = 3 3 3 3
kernel.kptr_restrict = 2

# ============================================================================
# FILE SYSTEM & NETWORK
# ============================================================================
fs.file-max = 2097152
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.core.somaxconn = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ============================================================================
# MEMORY MANAGEMENT
# ============================================================================
vm.max_map_count = 262144
vm.oom_kill_allocating_task = 1
EOF
    sysctl -p "$SYSCTL_CONF" > /dev/null
    ok "Created and applied $SYSCTL_CONF"
fi

# --- STEP 2: ZRAM ---
header "STEP 2: ZRAM (Compressed Swap)"
ZRAM_CONF="/etc/systemd/zram-generator.conf"
if ! pacman -Qi zram-generator &>/dev/null; then
    info "Installing zram-generator..."
    pacman -S --noconfirm zram-generator
else
    skip "zram-generator package"
fi

if [[ -f "$ZRAM_CONF" ]]; then
    skip "$ZRAM_CONF"
else
    cat > "$ZRAM_CONF" << 'EOF'
[zram0]
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
fs-type = swap
EOF
    ok "Created $ZRAM_CONF"
fi

if grep -q zram /proc/swaps; then
    skip "ZRAM already active"
else
    systemctl daemon-reload
    systemctl restart systemd-zram-setup@zram0
    ok "ZRAM activated"
fi

# --- STEP 3: I/O Scheduler ---
header "STEP 3: I/O Scheduler (NVMe/SSD/HDD)"
IOSCHED_RULES="/etc/udev/rules.d/60-ioschedulers.rules"
if [[ -f "$IOSCHED_RULES" ]]; then
    skip "$IOSCHED_RULES"
else
    cat > "$IOSCHED_RULES" << 'EOF'
# NVMe: kyber scheduler (lowest latency)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="kyber"

# SATA SSD: mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline"

# HDD (if any): BFQ
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
  ATTR{queue/scheduler}="bfq"
EOF
    udevadm control --reload
    udevadm trigger
    ok "Created $IOSCHED_RULES and reloaded udev"
fi

# --- STEP 4: Disable Watchdog ---
header "STEP 4: Disable Hardware Watchdog"
WATCHDOG_CONF="/etc/modprobe.d/disable-watchdog.conf"
if [[ -f "$WATCHDOG_CONF" ]]; then
    skip "$WATCHDOG_CONF"
else
    cat > "$WATCHDOG_CONF" << 'EOF'
blacklist sp5100_tco
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist wdat_wdt
EOF
    ok "Created $WATCHDOG_CONF"
    NEED_REINITRAMFS=1
fi

if grep -q "nowatchdog" /etc/default/grub 2>/dev/null; then
    skip "nowatchdog already in GRUB_CMDLINE_LINUX_DEFAULT"
else
    if [[ -f /etc/default/grub ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nowatchdog /' /etc/default/grub
        ok "Added nowatchdog to GRUB config"
        NEED_GRUB=1
    else
        warn "/etc/default/grub not found — skipping (are you using GRUB?)"
    fi
fi

# --- STEP 5: Transparent Hugepages ---
header "STEP 5: Transparent Hugepages Tuning"
THP_CONF="/etc/tmpfiles.d/thp.conf"
if [[ -f "$THP_CONF" ]]; then
    skip "$THP_CONF"
else
    cat > "$THP_CONF" << 'EOF'
w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409
EOF
    systemd-tmpfiles --create
    ok "Created $THP_CONF and applied"
fi

# --- STEP 6: Network Queue Discipline ---
header "STEP 6: Network Queue Discipline (fq_codel)"
if ! command -v tc &>/dev/null; then
    info "Installing iproute2..."
    pacman -S --noconfirm iproute2
else
    skip "iproute2 package"
fi

NETQDISC_SERVICE="/etc/systemd/system/network-qdisc.service"
if [[ -f "$NETQDISC_SERVICE" ]]; then
    skip "$NETQDISC_SERVICE"
else
    cat > "$NETQDISC_SERVICE" << 'EOF'
[Unit]
Description=Set network queue discipline to fq_codel
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'for iface in $(ip -o link show | awk -F": " "{print $2}" | grep -v lo); do /usr/bin/tc qdisc replace dev $iface root fq_codel 2>/dev/null || true; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now network-qdisc.service
    ok "Created and enabled network-qdisc.service"
fi

# --- STEP 7: PCI Latency Tuning ---
header "STEP 7: PCI Latency Tuning"
if ! command -v setpci &>/dev/null; then
    info "Installing pciutils..."
    pacman -S --noconfirm pciutils
else
    skip "pciutils package"
fi

PCI_SCRIPT="/usr/bin/pci-latency"
if [[ -f "$PCI_SCRIPT" ]]; then
    skip "$PCI_SCRIPT"
else
    cat > "$PCI_SCRIPT" << 'EOF'
#!/usr/bin/env sh
setpci -v -s '*:*' latency_timer=20 2>/dev/null || true
setpci -v -s '0:0' latency_timer=0 2>/dev/null || true
setpci -v -d "*:*:04xx" latency_timer=80 2>/dev/null || true
echo "PCI latency timers configured"
EOF
    chmod +x "$PCI_SCRIPT"
    ok "Created $PCI_SCRIPT"
fi

PCI_SERVICE="/etc/systemd/system/pci-latency.service"
if [[ -f "$PCI_SERVICE" ]]; then
    skip "$PCI_SERVICE"
else
    cat > "$PCI_SERVICE" << 'EOF'
[Unit]
Description=Set PCI latency timers
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pci-latency
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now pci-latency.service
    ok "Created and enabled pci-latency.service"
fi

# --- STEP 8: CPU DMA Latency ---
header "STEP 8: CPU DMA Latency (Audio Group Access)"
DMA_RULE="/etc/udev/rules.d/99-cpu-dma-latency.rules"
if [[ -f "$DMA_RULE" ]]; then
    skip "$DMA_RULE"
else
    cat > "$DMA_RULE" << 'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0666"
EOF
    udevadm control --reload
    udevadm trigger
    ok "Created $DMA_RULE"
fi

REAL_USER="${SUDO_USER:-$USER}"
if id -nG "$REAL_USER" | grep -qw audio; then
    skip "$REAL_USER already in audio group"
else
    usermod -aG audio "$REAL_USER"
    ok "Added $REAL_USER to audio group (re-login required)"
fi

# --- STEP 9: Zen Kernel ---
header "STEP 9: Zen Kernel Installation"
if ! pacman -Qi linux-zen &>/dev/null; then
    info "Installing Zen Kernel and Headers..."
    pacman -S --noconfirm linux-zen linux-zen-headers
    NEED_GRUB=1
else
    skip "Zen Kernel is already installed"
fi

# --- Regenerate initramfs if watchdog blacklist changed ---
if [[ $NEED_REINITRAMFS -eq 1 ]]; then
    header "Regenerating initramfs"
    mkinitcpio -P
    ok "initramfs regenerated"
fi

if [[ $NEED_GRUB -eq 1 ]]; then
    header "Regenerating GRUB config"
    if command -v grub-mkconfig &>/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
        ok "grub.cfg regenerated"
    else
        warn "grub-mkconfig not found — update your bootloader config manually"
    fi
fi

# ==================================================================
# SUMMARY
# ==================================================================
header "SUMMARY"
echo -e "  ${GREEN}✅ Sysctl tuning${NC}          (Memory + CPU + Network)"
echo -e "  ${GREEN}✅ ZRAM compression${NC}       (Virtual RAM expansion)"
echo -e "  ${GREEN}✅ I/O scheduler${NC}          ($(echo $PHYSICAL_DEVS | tr '\n' ' ') latency reduction)"
echo -e "  ${GREEN}✅ Watchdog disabled${NC}      (CPU interrupt reduction)"
echo -e "  ${GREEN}✅ THP configured${NC}         (Memory efficiency)"
echo -e "  ${GREEN}✅ Network QoS${NC}            (fq_codel)"
echo -e "  ${GREEN}✅ PCI latency${NC}            (Device responsiveness)"
echo -e "  ${GREEN}✅ Audio group access${NC}     (Real-time performance)"
echo -e "  ${GREEN}✅ Zen Kernel${NC}             (Latency-optimized scheduler)"
echo ""

if [[ $NEED_REINITRAMFS -eq 1 || $NEED_GRUB -eq 1 ]] || ! grep -q zram /proc/swaps; then
    echo -e "${BOLD}${YELLOW}A reboot is recommended to fully apply changes.${NC}"
    echo -e "  Run: ${CYAN}sudo reboot${NC}"
else
    echo -e "${BOLD}${GREEN}All changes already active — no reboot needed.${NC}"
fi

echo ""
echo -e "  Verify anytime with:   ${CYAN}sudo ./arch-optimize.sh --verify${NC}"
echo -e "  Roll back everything:  ${CYAN}sudo ./arch-optimize.sh --rollback${NC}"