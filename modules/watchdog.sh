
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

    if [[ "$BOOTLOADER" == "grub" ]]; then
        if grep -q "nowatchdog" /etc/default/grub 2>/dev/null; then
            skip "nowatchdog already in GRUB_CMDLINE_LINUX_DEFAULT"
        else
            if [[ -f /etc/default/grub ]]; then
                sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nowatchdog /' /etc/default/grub
                ok "Added nowatchdog to GRUB config"
                NEED_BOOTLOADER_UPDATE=1
            else
                warn "/etc/default/grub not found — skipping (are you using GRUB?)"
            fi
        fi
    elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
        local esp=$(get_systemd_boot_path)
        local updated=0
        if [[ -n "$esp" && -d "$esp/loader/entries" ]]; then
            for entry in "$esp/loader/entries"/*.conf; do
                if [[ -f "$entry" ]]; then
                    if grep -q "nowatchdog" "$entry" 2>/dev/null; then
                        skip "nowatchdog already in systemd-boot entry: $(basename "$entry")"
                    else
                        sed -i "/^options/ s/$/ nowatchdog/" "$entry"
                        sed -i 's/  */ /g' "$entry"
                        ok "Added nowatchdog to systemd-boot entry: $(basename "$entry")"
                        updated=1
                    fi
                fi
            done
        else
            warn "systemd-boot entries directory not found"
        fi

        if [[ -f /etc/kernel/cmdline ]]; then
            if grep -q "nowatchdog" /etc/kernel/cmdline 2>/dev/null; then
                skip "nowatchdog already in /etc/kernel/cmdline"
            else
                sed -i "s/$/ nowatchdog/" /etc/kernel/cmdline
                sed -i 's/  */ /g' /etc/kernel/cmdline
                ok "Added nowatchdog to /etc/kernel/cmdline"
                updated=1
                NEED_REINITRAMFS=1
            fi
        fi
        
        if [[ $updated -eq 1 ]]; then
            NEED_BOOTLOADER_UPDATE=1
        fi
    else
        warn "Unsupported bootloader: $BOOTLOADER — please add 'nowatchdog' to your boot options manually"
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

    if [[ "$BOOTLOADER" == "grub" ]]; then
        if grep -q "nowatchdog" /etc/default/grub 2>/dev/null; then
            sed -i -E 's/\bnowatchdog[[:space:]]*//' /etc/default/grub
            ok "Removed nowatchdog from GRUB_CMDLINE_LINUX_DEFAULT"
            NEED_BOOTLOADER_UPDATE=1
        fi
    elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
        local esp=$(get_systemd_boot_path)
        local updated=0
        if [[ -n "$esp" && -d "$esp/loader/entries" ]]; then
            for entry in "$esp/loader/entries"/*.conf; do
                if [[ -f "$entry" ]]; then
                    if grep -q "nowatchdog" "$entry" 2>/dev/null; then
                        sed -i -E 's/\bnowatchdog[[:space:]]*//' "$entry"
                        sed -i 's/[[:space:]]*$//' "$entry"
                        ok "Removed nowatchdog from systemd-boot entry: $(basename "$entry")"
                        updated=1
                    fi
                fi
            done
        fi

        if [[ -f /etc/kernel/cmdline ]]; then
            if grep -q "nowatchdog" /etc/kernel/cmdline 2>/dev/null; then
                sed -i -E 's/\bnowatchdog[[:space:]]*//' /etc/kernel/cmdline
                sed -i 's/[[:space:]]*$//' /etc/kernel/cmdline
                ok "Removed nowatchdog from /etc/kernel/cmdline"
                updated=1
                NEED_REINITRAMFS=1
            fi
        fi

        if [[ $updated -eq 1 ]]; then
            NEED_BOOTLOADER_UPDATE=1
        fi
    fi
}
