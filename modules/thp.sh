
apply_thp() {
    header "STEP 5: Transparent Hugepages Tuning"
    THP_CONF="/etc/tmpfiles.d/thp.conf"
    
    if [[ -f "$THP_CONF" ]]; then
        skip "$THP_CONF"
    else
        if [[ -f "$SCRIPT_DIR/config/thp.conf" ]]; then
            cp -f "$SCRIPT_DIR/config/thp.conf" "$THP_CONF"
            systemd-tmpfiles --create
            ok "Created $THP_CONF and applied"
        else
            warn "config/thp.conf template not found"
        fi
    fi
}

verify_thp() {
    echo -e "${BOLD}${CYAN}Transparent Hugepages:${NC}"
    if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        echo -e "  ${YELLOW}$(cat /sys/kernel/mm/transparent_hugepage/defrag)${NC}"
    else
        warn "Not available"
    fi
}

rollback_thp() {
    f="/etc/tmpfiles.d/thp.conf"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
}
