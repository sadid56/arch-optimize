
apply_ananicy() {
    header "STEP 10: Ananicy-cpp Auto-Nice Daemon"
    if ! pacman -Qi ananicy-cpp &>/dev/null; then
        info "Installing ananicy-cpp..."
        pacman -S --noconfirm ananicy-cpp
    else
        skip "ananicy-cpp package"
    fi

    # Copy config and rules
    if [[ -d "/etc/ananicy.d" ]]; then
        if [[ -f "$CONFIG_DIR/ananicy.conf" ]]; then
            cp -f "$CONFIG_DIR/ananicy.conf" /etc/ananicy.d/ananicy.conf
            ok "Copied ananicy.conf to /etc/ananicy.d/"
        fi
        if [[ -f "$CONFIG_DIR/development.rules" ]]; then
            cp -f "$CONFIG_DIR/development.rules" /etc/ananicy.d/development.rules
            ok "Copied development.rules to /etc/ananicy.d/"
        fi
    else
        warn "/etc/ananicy.d directory does not exist — check if ananicy-cpp installed correctly"
    fi

    if systemctl is-active --quiet ananicy-cpp.service; then
        systemctl reload ananicy-cpp.service 2>/dev/null || systemctl restart ananicy-cpp.service 2>/dev/null
        ok "Reloaded ananicy-cpp service to apply new rules"
    else
        systemctl daemon-reload
        systemctl enable --now ananicy-cpp.service
        ok "Enabled and started ananicy-cpp.service"
    fi
}

verify_ananicy() {
    echo -e "${BOLD}${CYAN}Ananicy-cpp Daemon Status:${NC}"
    ananicy_status=$(systemctl is-active ananicy-cpp.service 2>/dev/null || echo "inactive")
    if [[ "$ananicy_status" == "active" ]]; then
        rules_count=$(find /etc/ananicy.d -type f -name "*.rules" -exec grep -h '^[^#]' {} + 2>/dev/null | grep -v '^[[:space:]]*$' | wc -l)
        ok "active with ${YELLOW}${rules_count}${NC} rules loaded under /etc/ananicy.d/"
    else
        warn "$ananicy_status"
    fi
}

rollback_ananicy() {
    systemctl disable --now ananicy-cpp.service 2>/dev/null || true
    for f in /etc/ananicy.d/ananicy.conf /etc/ananicy.d/development.rules; do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            ok "Removed $f"
        else
            skip "$f (not present)"
        fi
    done
}
