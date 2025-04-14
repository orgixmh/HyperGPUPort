#!/bin/bash

# === HyperGPUPort Installer and Launcher Manager ===

APP_NAME="HyperGPUPort"
INSTALL_DIR="/opt/hypergpuport"
APP_EXEC="$HOME/.local/bin/hgp.sh"
APP_ICON="$INSTALL_DIR/hypergpuport.png"
USER_DESKTOP_FILE="$HOME/.local/share/applications/hypergpuport-vm-launcher.desktop"
USER_BIN_DIR="$HOME/.local/bin"
SCRIPT_SOURCE="$INSTALL_DIR/hgp.sh"

SYSTEMD_SERVICE_NAME="hypergpuport.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/$SYSTEMD_SERVICE_NAME"

SUDOERS_FILE="/etc/sudoers.d/hypergpuport"
SUDOERS_RULE="konstantinos ALL=(ALL) NOPASSWD: $INSTALL_DIR/start-win-gtk.sh, $INSTALL_DIR/start-win-linux.sh"

PROJECT_SOURCE_DIR="$(dirname "$(realpath "$0")")"

# Function to install files to /opt/hypergpuport/
install_files() {
    echo "Installing files to $INSTALL_DIR..."

    sudo mkdir -p "$INSTALL_DIR"
    sudo cp -r "$PROJECT_SOURCE_DIR/"* "$INSTALL_DIR/"
    sudo chmod -R 755 "$INSTALL_DIR"

    echo "Files installed to $INSTALL_DIR."
}

# Function to install the systemd service (but not enable it)
install_service() {
    echo "Installing systemd service (will not enable)..."

    sudo tee "$SYSTEMD_SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=HyperGPUPort VM Passthrough
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/switchOS.sh
User=root
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload

    echo "Systemd service installed but not enabled."
}

# Function to uninstall the systemd service
uninstall_service() {
    echo "Uninstalling systemd service..."

    sudo systemctl disable "$SYSTEMD_SERVICE_NAME" >/dev/null 2>&1 || true
    sudo rm -f "$SYSTEMD_SERVICE_PATH"
    sudo systemctl daemon-reload

    echo "Systemd service removed."
}

# Function to install sudoers rule
install_sudoers() {
    echo "Installing sudoers rule..."

    echo "$SUDOERS_RULE" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"

    echo "Sudoers rule installed."
}

# Function to uninstall sudoers rule
uninstall_sudoers() {
    echo "Uninstalling sudoers rule..."

    sudo rm -f "$SUDOERS_FILE"

    echo "Sudoers rule removed."
}

# Function to install the desktop launcher
install_launcher() {
    echo "Installing application launcher..."

    if [ ! -f "$APP_ICON" ]; then
        echo "Icon not found at $APP_ICON"
        exit 1
    fi

    mkdir -p "$USER_BIN_DIR"
    cp "$SCRIPT_SOURCE" "$APP_EXEC"
    chmod +x "$APP_EXEC"

    mkdir -p "$HOME/.local/share/applications/"

    cat > "$USER_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=$APP_NAME
Comment=Launch Windows VM in Passthrough or Linux Window mode
Exec=$APP_EXEC
Icon=$APP_ICON
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=true
EOF

    update-desktop-database "$HOME/.local/share/applications/"

    echo "Launcher installed successfully."
}

# Function to uninstall the desktop launcher
uninstall_launcher() {
    echo "Uninstalling application launcher..."

    rm -f "$USER_DESKTOP_FILE"
    rm -f "$APP_EXEC"
    update-desktop-database "$HOME/.local/share/applications/"

    echo "Launcher removed successfully."
}

# Process install or uninstall argument
if [ "$1" == "--install" ]; then
    install_files
    install_launcher
    install_service
    install_sudoers
    echo "Installation completed successfully."
    exit 0
fi

if [ "$1" == "--uninstall" ]; then
    uninstall_launcher
    uninstall_service
    uninstall_sudoers
    echo "Uninstallation completed successfully."
    exit 0
fi

# If no --install or --uninstall, proceed to GUI launcher

# Check if zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Zenity is required but not installed. Install it with: sudo apt install zenity"
    exit 1
fi

# Show selection dialog
CHOICE=$(zenity --list --title="$APP_NAME" --width=1500 --height=500 --radiolist \
  --column "Select" --column "Mode" --column "Description" \
  TRUE "Linux Window Mode" "Run Windows inside a Linux window (virtual GPU)" \
  FALSE "Full Passthrough Mode" "Run Windows with GPU passthrough (full performance, requires monitor switch)" \
  FALSE "Kill VM" "Force kill any running QEMU VM" \
  FALSE "Change VM Settings" "Configure VM settings (not implemented yet)" \
)

# Check cancel or close window
if [ $? -ne 0 ]; then
    exit 0
fi

# Process choice
case "$CHOICE" in
    "Linux Window Mode")
        sudo "$INSTALL_DIR/start-win-gtk.sh" || zenity --error --title="$APP_NAME" --text="Error: Failed to start Linux window mode."
        ;;
    "Full Passthrough Mode")
        sudo "$INSTALL_DIR/start-win-linux.sh" || zenity --error --title="$APP_NAME" --text="Error: Failed to start passthrough VM."
        ;;
    "Kill VM")
        VM_PID=$(pgrep -f qemu-system-x86_64)
        if [ -n "$VM_PID" ]; then
            pkexec kill -9 "$VM_PID"
            zenity --info --title="$APP_NAME" --text="VM process killed (PID $VM_PID)."
        else
            zenity --info --title="$APP_NAME" --text="No running VM process found."
        fi
        ;;
    "Change VM Settings")
        zenity --info --title="$APP_NAME" --text="Feature not implemented yet."
        ;;
    *)
        zenity --error --title="$APP_NAME" --text="Unknown option selected."
        exit 1
        ;;
esac
