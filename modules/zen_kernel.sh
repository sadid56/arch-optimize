
apply_zen_kernel() {
    header "STEP 9: Zen Kernel Installation"
    
    local installed_zen=0
    local installed_headers=0
    
    if ! pacman -Qi linux-zen &>/dev/null; then
        info "Installing Zen Kernel..."
        pacman -S --noconfirm linux-zen
        NEED_GRUB=1
        installed_zen=1
    fi
    
    if ! pacman -Qi linux-zen-headers &>/dev/null; then
        info "Installing Zen Kernel Headers..."
        pacman -S --noconfirm linux-zen-headers
        installed_headers=1
    fi
    
    if [[ $installed_zen -eq 0 && $installed_headers -eq 0 ]]; then
        skip "Zen Kernel and Headers are already installed"
    fi
}

verify_zen_kernel() {
    echo -e "${BOLD}${CYAN}Kernel Version:${NC}"
    echo -e "  Running kernel: ${YELLOW}$(uname -r)${NC}"
}

rollback_zen_kernel() {
    # Match original rollback behaviour (does not uninstall packages)
    :
}
