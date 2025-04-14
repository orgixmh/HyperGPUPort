#!/bin/bash
DNSMASQ_PID_FILE="/tmp/vm_dnsmasq.pid"
# Optional: Add your USB sound card (Razer Barracuda X)
USB_SOUND_VENDOR="1532"
USB_SOUND_PRODUCT="054e"

start_dnsmasq() {
    echo "Starting dnsmasq for TAP interface..."

    sudo dnsmasq --interface=tap0 --bind-interfaces --except-interface=lo \
    --dhcp-range=192.168.100.2,192.168.100.254,12h \
    --dhcp-option=3,192.168.100.1 \
    --dhcp-option=6,8.8.8.8 \
    --log-queries --log-dhcp \
    --pid-file=$DNSMASQ_PID_FILE &

    sleep 1  # Give it a moment to start
    if [ -f "$DNSMASQ_PID_FILE" ]; then
        echo "dnsmasq started successfully (PID $(cat $DNSMASQ_PID_FILE))"
    else
        echo "Failed to start dnsmasq."
    fi
}

stop_dnsmasq() {
    echo "Stopping dnsmasq..."

    if [ -f "$DNSMASQ_PID_FILE" ]; then
        sudo kill "$(cat $DNSMASQ_PID_FILE)" && sudo rm -f "$DNSMASQ_PID_FILE"
        echo "dnsmasq stopped."
    else
        echo "No dnsmasq PID file found. Skipping."
    fi
}
echo "=== Windows VM: Auto-detecting USB keyboard and mouse ==="

# Find first keyboard
KEYBOARD=$(lsusb | grep -i -E 'keyboard|kbd' | head -n 1)
if [ -z "$KEYBOARD" ]; then
    echo "[WARN] No keyboard detected! Proceeding anyway..."
else
    KEYBOARD_VENDOR=$(echo $KEYBOARD | awk '{print $6}' | cut -d: -f1)
    KEYBOARD_PRODUCT=$(echo $KEYBOARD | awk '{print $6}' | cut -d: -f2)
    echo "[INFO] Keyboard detected: VendorID=0x$KEYBOARD_VENDOR, ProductID=0x$KEYBOARD_PRODUCT"
fi

# Find first mouse
MOUSE=$(lsusb | grep -i -E 'mouse' | head -n 1)
if [ -z "$MOUSE" ]; then
    echo "[WARN] No mouse detected! Proceeding anyway..."
else
    MOUSE_VENDOR=$(echo $MOUSE | awk '{print $6}' | cut -d: -f1)
    MOUSE_PRODUCT=$(echo $MOUSE | awk '{print $6}' | cut -d: -f2)
    echo "[INFO] Mouse detected: VendorID=0x$MOUSE_VENDOR, ProductID=0x$MOUSE_PRODUCT"
fi


echo "=== Configuring paths and hardware ==="

# OVMF 4M firmware paths
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.fd"

# Prepare OVMF vars copy (VM writes to it)
cp "$OVMF_VARS" /opt/hypergpuport/OVMF_VARS_4M.fd
# Define physical Windows disk
DISK="/dev/sdc"

echo "=== [VM Clean TAP Networking Setup] ==="

# Step 1: Detect physical network interface for NAT
DEFAULT_IFACE=$(ip route show default 0.0.0.0/0 | awk '{print $5}')

if [ -z "$DEFAULT_IFACE" ]; then
    echo "Could not detect the default network interface."
    exit 1
fi

echo "Default network interface detected: $DEFAULT_IFACE"

# Step 2: Prepare TAP interface
TAP_IFACE="tap0"

# Check if tap0 already exists
if ip link show "$TAP_IFACE" > /dev/null 2>&1; then
    echo "TAP interface '$TAP_IFACE' already exists."
else
    echo "  Creating TAP interface '$TAP_IFACE'..."
    sudo ip tuntap add dev "$TAP_IFACE" mode tap
    sudo ip addr add 192.168.100.1/24 dev "$TAP_IFACE"
    sudo ip link set dev "$TAP_IFACE" up
    echo "TAP interface '$TAP_IFACE' created."
fi

# Step 3: Setup NAT for internet access
echo "Setting up NAT for '$TAP_IFACE' -> '$DEFAULT_IFACE'..."
sudo iptables -t nat -C POSTROUTING -o "$DEFAULT_IFACE" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -o "$DEFAULT_IFACE" -j MASQUERADE

sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo "NAT configured."
start_dnsmasq
# Step 4: Launch QEMU

echo "=== Launching Windows VM ==="

qemu-system-x86_64 \
-enable-kvm \
-machine type=q35,accel=kvm \
-m 9192 \
-smp 10,sockets=1,cores=5,threads=2 \
-cpu host,kvm=off,hv-vendor-id=1234567890ab,hv-time,hv-relaxed,hv-vapic,hv-spinlocks=0x1fff \
-bios "$OVMF_CODE" \
-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
-drive if=pflash,format=raw,file=/opt/hypergpuport/OVMF_VARS_4M.ms.fd \
-device vfio-pci,host=03:00.0,multifunction=on,x-vga=on \
-device vfio-pci,host=03:00.1 \
-drive file="$DISK",format=raw,if=none,id=hd0,cache=none,aio=io_uring \
-device virtio-blk-pci,drive=hd0,num-queues=4 \
-netdev tap,id=net0,ifname="$TAP_IFACE",script=no,downscript=no \
-device virtio-net-pci,netdev=net0 \
-display none \
-vga none \
-global ICH9-LPC.disable_s3=1 -global ICH9-LPC.disable_s4=1 \
-drive file=/opt/hypergpuport/virtio-win-0.1.271.iso,media=cdrom \
-usb \
${MOUSE:+-device usb-host,vendorid=0x$MOUSE_VENDOR,productid=0x$MOUSE_PRODUCT} \
${KEYBOARD:+-device usb-host,vendorid=0x$KEYBOARD_VENDOR,productid=0x$KEYBOARD_PRODUCT} \
-device usb-host,vendorid=0x$USB_SOUND_VENDOR,productid=0x$USB_SOUND_PRODUCT

echo "=== Windows VM exited ==="
echo "Cleaning up networking..."
sudo ip link set dev "$TAP_IFACE" down
sudo ip tuntap del dev "$TAP_IFACE" mode tap
echo "Cleaned up TAP interface."
stop_dnsmasq
echo "All done!"
