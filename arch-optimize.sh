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

# Detect physical disks dynamically (NVMe, SATA SSDs, HDDs, etc. - excluding virtual/zram devices)
PHYSICAL_DEVS=$(lsblk -dno NAME,TYPE | awk '$2=="disk" && $1 !~ /^zram/ && $1 !~ /^loop/ {print $1}' || true)
PHYSICAL_DEVS=${PHYSICAL_DEVS:-nvme0n1}

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Determine directories (supports local running and system-wide package install)
if [[ -d "$SCRIPT_DIR/modules" ]]; then
    MODULES_DIR="$SCRIPT_DIR/modules"
    CONFIG_DIR="$SCRIPT_DIR/config"
else
    MODULES_DIR="/usr/share/arch-optimize/modules"
    CONFIG_DIR="/usr/share/arch-optimize/config"
fi

# Source all module scripts
for module_script in "$MODULES_DIR"/*.sh; do
    if [[ -f "$module_script" ]]; then
        source "$module_script"
    fi
done

# Defined order of execution
MODULES=(
    sysctl
    zram
    io_scheduler
    watchdog
    thp
    network_qdisc
    pci_latency
    cpu_dma_latency
    zen_kernel
    ananicy
)

# ==================================================================
# ROLLBACK MODE
# ==================================================================
rollback() {
    header "ROLLING BACK ALL OPTIMIZATIONS"

    for m in "${MODULES[@]}"; do
        if declare -f "rollback_$m" > /dev/null; then
            "rollback_$m"
        fi
    done

    # Re-apply kernel parameters
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

    if [[ $NEED_REINITRAMFS -eq 1 ]]; then
        if command -v mkinitcpio &>/dev/null; then
            mkinitcpio -P
            ok "Regenerated initramfs"
        fi
    fi

    echo ""
    echo -e "${BOLD}${GREEN}Rollback complete. Reboot to fully restore vanilla state:${NC} sudo reboot"
    exit 0
}

# ==================================================================
# VERIFY MODE
# ==================================================================
verify() {
    header "OPTIMIZATION VERIFICATION"

    for m in "${MODULES[@]}"; do
        if declare -f "verify_$m" > /dev/null; then
            "verify_$m"
            echo ""
        fi
    done

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
# APPLY MODE
# ==================================================================
header "PRE-FLIGHT SYSTEM CHECK"
info "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
info "RAM: $(free -h | awk '/^Mem:/{print $2}')"
info "Storage: $(lsblk -dno NAME,SIZE,TYPE | grep -v loop)"
info "Physical disks detected: $(echo $PHYSICAL_DEVS | tr '\n' ' ')"

for m in "${MODULES[@]}"; do
    if declare -f "apply_$m" > /dev/null; then
        "apply_$m"
    fi
done

# --- Post-apply operations ---

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
echo -e "  ${GREEN}✅ Ananicy-cpp${NC}            (Auto-nice priority daemon)"
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