# HyperGPUPort

Dynamic Hardware Passthrough for GPU Virtualization

HyperGPUPort is an advanced Linux utility that dynamically detaches your GPU from the Linux host and assigns it to a fast, dedicated Windows virtual machine (VM). It automates all networking, device binding, and cleanup — giving you bare-metal performance without the hassle.

Forget about dual booting or rebooting. Launch your Windows environment with full GPU acceleration directly from your Linux desktop, cleanly and safely.

---

## Features

- Dynamic GPU passthrough (VFIO)
- Automated networking (TAP interface + dnsmasq + NAT)
- Clean system recovery after VM shutdown
- USB auto-detection (keyboard, mouse, sound devices)
- Easy integration with systemd for auto-starting on boot
- Logging and diagnostics for troubleshooting
- Clean sudo-less operation using fine-grained sudoers rules
- No kernel patches, works with upstream Linux

---

## Roadmap

Planned features for future versions of HyperGPUPort:

- Automatic GPU Detection  
  Detect and bind any GPU (NVIDIA / AMD / Intel ARC) automatically.

- Hypervisor Signature Spoofer  
  Spoof hypervisor signatures for newer GPU driver restrictions and bypass VM detection.

- GUI Configuration Tool  
  Graphical configuration of:
  - CPU and Memory allocation
  - USB passthrough devices
  - Disk images or physical drives
  - Network mode selection (bridge, NAT, isolated)

- Virtual Display Forwarding  
  Integrate solutions like Looking Glass for seamless display output to host window.

- Auto VM startup and resume  
  Option to auto-start the VM when Linux boots or when the user logs in.

- Multiple VM Profiles  
  Manage different VM configurations (Gaming, Work, Test environments).

- Better VPN compatibility  
  Auto-detection of VPN routes and automatic bypass for VM traffic.

---

## Requirements

- Linux host with IOMMU and VFIO enabled
- QEMU / KVM virtualization stack
- OVMF (UEFI firmware for VMs)
- dnsmasq (for internal DHCP server)
- sudo access for initial setup
- GPU that supports passthrough (NVIDIA, AMD, Intel)

---

## Installation

1. Clone this repository

```bash
git clone https://github.com/yourusername/hypergpuport.git
cd hypergpuport
````


2. Edit your /etc/sudoers
```bash
sudo visudo
````

Add the following line, replacing kostas with your actual username:
(will soon add it to the install script)
```bash
kostas ALL=(ALL) NOPASSWD: /opt/hypergpuport/start-win-gtk.sh, /opt/hypergpuport/start-win-linux.sh
```
3. run the installer

```bash
sudo hgp --install
```
