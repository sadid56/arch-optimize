
apply_io_scheduler() {
    header "STEP 3: I/O Scheduler (NVMe/SSD/HDD)"
    IOSCHED_RULES="/etc/udev/rules.d/60-ioschedulers.rules"
    
    if [[ -f "$IOSCHED_RULES" ]]; then
        skip "$IOSCHED_RULES"
    else
        if [[ -f "$SCRIPT_DIR/config/60-ioschedulers.rules" ]]; then
            cp -f "$SCRIPT_DIR/config/60-ioschedulers.rules" "$IOSCHED_RULES"
            udevadm control --reload
            udevadm trigger
            ok "Created $IOSCHED_RULES and reloaded udev"
        else
            warn "config/60-ioschedulers.rules template not found"
        fi
    fi
}

verify_io_scheduler() {
    echo -e "${BOLD}${CYAN}I/O Schedulers:${NC}"
    for dev in $PHYSICAL_DEVS; do
        sched_path="/sys/block/${dev}/queue/scheduler"
        if [[ -f "$sched_path" ]]; then
            echo -e "  ${dev}: ${YELLOW}$(cat "$sched_path")${NC}"
        else
            warn "${dev} not found"
        fi
    done
}

rollback_io_scheduler() {
    f="/etc/udev/rules.d/60-ioschedulers.rules"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
    udevadm control --reload 2>/dev/null || true
}
