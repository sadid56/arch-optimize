
apply_network_qdisc() {
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
        if [[ -f "$CONFIG_DIR/network-qdisc.service" ]]; then
            cp -f "$CONFIG_DIR/network-qdisc.service" "$NETQDISC_SERVICE"
            systemctl daemon-reload
            systemctl enable --now network-qdisc.service
            ok "Created and enabled network-qdisc.service"
        else
            warn "config/network-qdisc.service template not found"
        fi
    fi
}

verify_network_qdisc() {
    echo -e "${BOLD}${CYAN}Network Qdisc Service:${NC}"
    net_status=$(systemctl is-active network-qdisc.service 2>/dev/null || echo "inactive")
    [[ "$net_status" == "active" ]] && ok "$net_status" || warn "$net_status"
}

rollback_network_qdisc() {
    f="/etc/systemd/system/network-qdisc.service"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
    systemctl disable --now network-qdisc.service 2>/dev/null || true
}
