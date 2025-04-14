#!/bin/bash


GPU="0000:03:00.0"
AUDIO="0000:03:00.1"
GPU_ID="10de 1380"
AUDIO_ID="10de 0fbc"

echo "=== Step 1: Unbind devices from vfio-pci ==="
if [ -L /sys/bus/pci/devices/$GPU/driver ]; then
    echo -n "$GPU" | sudo tee /sys/bus/pci/devices/$GPU/driver/unbind > /dev/null  &
    echo "" | sudo tee /sys/bus/pci/devices/$GPU/driver_override  &
else
    echo "[INFO] GPU already unbound."
fi

if [ -L /sys/bus/pci/devices/$AUDIO/driver ]; then
    echo -n "$AUDIO" | sudo tee /sys/bus/pci/devices/$AUDIO/driver/unbind > /dev/null  &
    echo "" | sudo tee /sys/bus/pci/devices/$GPU/driver_override  &
else
    echo "[INFO] Audio device already unbound."
fi

echo "=== Step 2: Reload NVIDIA modules ==="

MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

for mod in $MODULES; do
    if ! lsmod | grep -q "^$mod"; then
        echo "[INFO] Loading module: $mod"
        sudo modprobe $mod
    else
        echo "[INFO] Module $mod already loaded."
    fi
done

echo "=== Step 3: Bind devices back to NVIDIA driver ==="

echo $GPU_ID | sudo tee /sys/bus/pci/drivers/nvidia/new_id > /dev/null  &
echo $AUDIO_ID | sudo tee /sys/bus/pci/drivers/snd_hda_intel/new_id > /dev/null  &

echo "=== Step 4: Start display manager ==="

sudo systemctl start display-manager || echo "[INFO] Display manager could not be started (maybe headless system)."

echo "=== GPU Restore Complete! ==="
