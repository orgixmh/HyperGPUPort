#!/bin/bash

GPU="0000:03:00.0"
AUDIO="0000:03:00.1"
GPU_ID="10de 1380"
AUDIO_ID="10de 0fbc"

echo "=== Step 1: Stop display manager ==="
sudo systemctl stop display-manager || echo "[INFO] Display manager already stopped."

echo "=== Step 2: Kill processes using NVIDIA devices ==="
PIDS=$(sudo lsof /dev/nvidia* /dev/dri/* 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
if [ -z "$PIDS" ]; then
    echo "[INFO] No processes using NVIDIA devices."
else
    echo "[INFO] Killing processes: $PIDS"
    for PID in $PIDS; do
        sudo kill -9 $PID || true
    done
fi

echo "=== Step 3: Unload NVIDIA kernel modules ==="
MODULES="nvidia_drm nvidia_modeset nvidia_uvm nvidia nvidiafb nouveau"
for mod in $MODULES; do
    if lsmod | grep -q "^$mod"; then
        echo "[INFO] Removing module: $mod"
        sudo modprobe -r $mod || sudo rmmod -f $mod || echo "[WARN] Could not remove $mod"
    else
        echo "[INFO] Module $mod not loaded."
    fi
done

echo "=== Step 4: Rescan PCIe bus to ensure devices are visible ==="
echo 1 | sudo tee /sys/bus/pci/rescan > /dev/null  &
sleep 2

echo "=== Step 5: Load vfio-pci module and adding NVIDIA id's==="
sudo tee /sys/bus/pci/drivers/vfio-pci/new_id <<< "$GPU_ID" &
sudo tee /sys/bus/pci/drivers/vfio-pci/new_id <<< "$AUDIO_ID" &
sleep 2
sudo modprobe vfio-pci
sleep 1

echo "=== Step 6: Force bind GPU and Audio to vfio-pci ==="

echo "vfio-pci" | sudo tee /sys/bus/pci/devices/$GPU/driver_override > /dev/null  &
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/$AUDIO/driver_override > /dev/null  &

echo "$GPU" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind > /dev/null  &
echo "$AUDIO" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind > /dev/null  &

echo "=== Step 7: Clean up driver override ==="
echo "" | sudo tee /sys/bus/pci/devices/$GPU/driver_override > /dev/null  &
echo "" | sudo tee /sys/bus/pci/devices/$AUDIO/driver_override > /dev/null  &
sleep 2

echo "=== GPU Passthrough Preparation Complete ==="
echo "[INFO] You can now start your VM!"
