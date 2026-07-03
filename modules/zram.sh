
apply_zram() {
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
        if [[ -f "$SCRIPT_DIR/config/zram-generator.conf" ]]; then
            cp -f "$SCRIPT_DIR/config/zram-generator.conf" "$ZRAM_CONF"
            ok "Created $ZRAM_CONF"
        else
            warn "config/zram-generator.conf template not found"
        fi
    fi

    if grep -q zram /proc/swaps; then
        skip "ZRAM already active"
    else
        systemctl daemon-reload
        systemctl restart systemd-zram-setup@zram0
        ok "ZRAM activated"
    fi
}

verify_zram() {
    echo -e "${BOLD}${CYAN}ZRAM Status:${NC}"
    zram_out=$(grep zram /proc/swaps || true)
    [[ -n "$zram_out" ]] && echo -e "  ${YELLOW}${zram_out}${NC}" || warn "No ZRAM device active"
}

rollback_zram() {
    f="/etc/systemd/zram-generator.conf"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
    systemctl stop systemd-zram-setup@zram0 2>/dev/null || true
}
