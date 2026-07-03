
apply_sysctl() {
    header "STEP 1: Sysctl Optimizations"
    SYSCTL_CONF="/etc/sysctl.d/70-performance-tuning.conf"
    
    if [[ -f "$SYSCTL_CONF" ]]; then
        skip "$SYSCTL_CONF"
    else
        if [[ -f "$CONFIG_DIR/70-performance-tuning.conf" ]]; then
            cp -f "$CONFIG_DIR/70-performance-tuning.conf" "$SYSCTL_CONF"
            sysctl -p "$SYSCTL_CONF" > /dev/null
            ok "Created and applied $SYSCTL_CONF"
        else
            warn "config/70-performance-tuning.conf template not found"
        fi
    fi
}

verify_sysctl() {
    echo -e "${BOLD}${CYAN}SYSCTL Settings:${NC}"
    echo -e "  vm.swappiness: ${YELLOW}$(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  kernel.nmi_watchdog: ${YELLOW}$(sysctl -n kernel.nmi_watchdog 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  vm.vfs_cache_pressure: ${YELLOW}$(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo 'N/A')${NC}"
}

rollback_sysctl() {
    f="/etc/sysctl.d/70-performance-tuning.conf"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
    sysctl --system 2>/dev/null || true
}
