
apply_watchdog() {
    header "STEP 4: Disable Hardware Watchdog"
    WATCHDOG_CONF="/etc/modprobe.d/disable-watchdog.conf"
    
    if [[ -f "$WATCHDOG_CONF" ]]; then
        skip "$WATCHDOG_CONF"
    else
        if [[ -f "$CONFIG_DIR/disable-watchdog.conf" ]]; then
            cp -f "$CONFIG_DIR/disable-watchdog.conf" "$WATCHDOG_CONF"
            ok "Created $WATCHDOG_CONF"
            NEED_REINITRAMFS=1
        else
            warn "config/disable-watchdog.conf template not found"
        fi
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
}

verify_watchdog() {
    echo -e "${BOLD}${CYAN}Watchdog Status:${NC}"
    watchdog_out=$(lsmod | grep -E "sp5100|iTCO|wdat" || true)
    [[ -n "$watchdog_out" ]] && echo -e "  ${YELLOW}${watchdog_out}${NC}" || ok "Watchdogs disabled"
}

rollback_watchdog() {
    f="/etc/modprobe.d/disable-watchdog.conf"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
        NEED_REINITRAMFS=1
    else
        skip "$f (not present)"
    fi

    if grep -q "nowatchdog" /etc/default/grub 2>/dev/null; then
        sed -i -E 's/\bnowatchdog[[:space:]]*//' /etc/default/grub
        ok "Removed nowatchdog from GRUB_CMDLINE_LINUX_DEFAULT"
        NEED_GRUB=1
    fi
}
