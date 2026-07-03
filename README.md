# 🚀 Arch Linux Performance Optimizer

An automated, safe, and idempotent script to optimize Arch Linux for low-latency desktop use, gaming, and real-time audio workloads. 

This script applies system-level tweaks spanning virtual memory, storage I/O, network queuing, hardware latency, and process scheduling. It is fully reversible and checks for existing configurations before applying changes.

---

## 🛠️ What This Script Optimizes

| Optimization | Target Area | Description |
| :--- | :--- | :--- |
| **Sysctl Tuning** | CPU, RAM & Net | Tweaks swappiness (`100` for ZRAM), dirty page limits, scheduling migration costs, and enables **BBR congestion control** with **FQ pacing**. |
| **ZRAM Swap** | Virtual Memory | Installs and configures `zram-generator` with `zstd` compression, expanding effective RAM. |
| **I/O Scheduler** | Storage | Configures udev rules: `kyber` for NVMe SSDs, `mq-deadline` for SATA SSDs, and `bfq` for traditional HDDs. |
| **Disable Watchdogs** | CPU interrupts | Blacklists hardware watchdog modules to prevent periodic CPU interrupts and improve performance. |
| **THP Tuning** | Memory | Sets Transparent Hugepages defrag to `defer+madvise` to prevent memory allocation freezes. |
| **Network QoS** | Network | Implements a systemd service that sets the queue discipline to `fq_codel` across all network interfaces to eliminate bufferbloat. |
| **PCI Latency** | Bus responsiveness | Adjusts PCI latency timers via a startup service to prioritize multimedia/audio devices. |
| **CPU DMA Latency** | Real-Time Audio | Authorizes the `audio` group to write to `/dev/cpu_dma_latency` to disable deep C-states for real-time tasks. |
| **Zen Kernel** | CPU & Scheduling | Auto-installs `linux-zen` and headers to provide a responsiveness-oriented scheduler and lower desktop latency. |
| **Ananicy-cpp** | CPU & Scheduling | Installs and enables `ananicy-cpp` service to dynamically manage process niceness and improve responsiveness. |

---

## 🚀 Getting Started

### 📋 Prerequisites

* **OS**: Arch Linux (or Arch-based distributions).
* **Permissions**: Must be run with `sudo` / root privileges.
* **Dependencies**: The script will automatically install necessary packages (`zram-generator`, `iproute2`, `pciutils`, `linux-zen`, `linux-zen-headers`, and `ananicy-cpp`) via `pacman` if they are missing.

### 📥 Installation & Execution

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sadid56/artune
   ```
2. **Make the script executable:**
   ```bash
   chmod +x artune
   ```

3. **Apply the optimizations:**
   ```bash
   sudo ./artune
   ```

4. **Reboot the system** to fully apply bootloader (GRUB) changes and initialize ZRAM swap:
   ```bash
   sudo reboot
   ```

---

## ⚙️ Usage Modes

The script supports three modes: **Apply (default)**, **Verify**, and **Rollback**.

### 🔍 1. Verify Active Settings
You can check the current status of all optimizations at any time without making changes:
```bash
sudo ./artune --verify
```

### 🔄 2. Roll Back Changes
If you wish to completely revert all modifications made by this script and restore your system to its vanilla state:
```bash
sudo ./artune --rollback
sudo reboot
```

---

## ⚠️ Important Considerations

> [!WARNING]
> * **Bootloader**: The watchdog disable parameter (`nowatchdog`) is added to `/etc/default/grub` and regenerates your GRUB configuration automatically. If you use a different bootloader (e.g., `systemd-boot` or `rrefind`), you will need to add `nowatchdog` to your bootloader options manually.
> * **Real-Time Audio**: The script adds your user to the `audio` group to allow low-latency access to CPU DMA. You must log out and log back in for this group membership to take effect.
