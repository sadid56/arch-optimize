
apply_pci_latency() {
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
        if [[ -f "$CONFIG_DIR/pci-latency.sh" ]]; then
            cp -f "$CONFIG_DIR/pci-latency.sh" "$PCI_SCRIPT"
            chmod +x "$PCI_SCRIPT"
            ok "Created $PCI_SCRIPT"
        else
            warn "config/pci-latency.sh template not found"
        fi
    fi

    PCI_SERVICE="/etc/systemd/system/pci-latency.service"
    if [[ -f "$PCI_SERVICE" ]]; then
        skip "$PCI_SERVICE"
    else
        if [[ -f "$CONFIG_DIR/pci-latency.service" ]]; then
            cp -f "$CONFIG_DIR/pci-latency.service" "$PCI_SERVICE"
            systemctl daemon-reload
            systemctl enable --now pci-latency.service
            ok "Created and enabled pci-latency.service"
        else
            warn "config/pci-latency.service template not found"
        fi
    fi
}

verify_pci_latency() {
    echo -e "${BOLD}${CYAN}PCI Latency Service:${NC}"
    pci_status=$(systemctl is-active pci-latency.service 2>/dev/null || echo "inactive")
    [[ "$pci_status" == "active" ]] && ok "$pci_status" || warn "$pci_status"
}

rollback_pci_latency() {
    for f in /usr/bin/pci-latency /etc/systemd/system/pci-latency.service; do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            ok "Removed $f"
        else
            skip "$f (not present)"
        fi
    done
    systemctl disable --now pci-latency.service 2>/dev/null || true
}
