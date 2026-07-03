
apply_cpu_dma_latency() {
    header "STEP 8: CPU DMA Latency (Audio Group Access)"
    DMA_RULE="/etc/udev/rules.d/99-cpu-dma-latency.rules"
    
    if [[ -f "$DMA_RULE" ]]; then
        skip "$DMA_RULE"
    else
        if [[ -f "$CONFIG_DIR/99-cpu-dma-latency.rules" ]]; then
            cp -f "$CONFIG_DIR/99-cpu-dma-latency.rules" "$DMA_RULE"
            udevadm control --reload
            udevadm trigger
            ok "Created $DMA_RULE"
        else
            warn "config/99-cpu-dma-latency.rules template not found"
        fi
    fi

    REAL_USER="${SUDO_USER:-$USER}"
    if id -nG "$REAL_USER" | grep -qw audio; then
        skip "$REAL_USER already in audio group"
    else
        usermod -aG audio "$REAL_USER"
        ok "Added $REAL_USER to audio group (re-login required)"
    fi
}

verify_cpu_dma_latency() {
    # Handled implicitly or omitted in verify to keep original output structure
    :
}

rollback_cpu_dma_latency() {
    f="/etc/udev/rules.d/99-cpu-dma-latency.rules"
    if [[ -e "$f" ]]; then
        rm -f "$f"
        ok "Removed $f"
    else
        skip "$f (not present)"
    fi
}
