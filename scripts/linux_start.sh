#!/bin/bash

# This script is run without root privilege
# inside the container when it is started.

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_linux

# Load display configuration (falls back to defaults if display.conf is absent)
RESOLUTION="${vnc_default_resolution}"
SCALE=1
[ -f "$script_dir/display.conf" ] && source "$script_dir/display.conf"

# Apply scaling to UI components before LXDE starts.
DPI=$((96 * SCALE))
DPI_1024=$((DPI * 1024))          # lxsession stores DPI as integer * 1024
PANEL_SIZE=$((26 * SCALE))        # lxpanel height and icon size (base 26px)

# Vivado scales with iXft/DPI in lxsession (e.g. SCALE=2 → 196608)
if [ -f "/home/user/.config/lxsession/LXDE/desktop.conf" ]; then
    sed -i "s|iXft/DPI=[0-9]*|iXft/DPI=$DPI_1024|" /home/user/.config/lxsession/LXDE/desktop.conf
fi

# Taskbar height and icon size
mkdir -p /home/user/.config/lxpanel/LXDE/panels
if [ ! -f "/home/user/.config/lxpanel/LXDE/panels/panel" ]; then
    cp "$script_dir/default/lxpanel-panel.conf" /home/user/.config/lxpanel/LXDE/panels/panel
fi
sed -i "s/height=[0-9]*/height=$PANEL_SIZE/" /home/user/.config/lxpanel/LXDE/panels/panel
sed -i "s/iconsize=[0-9]*/iconsize=$PANEL_SIZE/" /home/user/.config/lxpanel/LXDE/panels/panel

# generate encoded password file from plain text
mkdir /home/user/.vnc &> /dev/null
cat "$script_dir/vncpasswd" | vncpasswd -f > /home/user/.vnc/passwd

vncserver -DisconnectClients -NeverShared -nocursor -geometry "$RESOLUTION" -dpi "$DPI" -SecurityTypes VncAuth -PasswordFile /home/user/.vnc/passwd -localhost no -verbose -fg -RawKeyboard -RemapKeys "0xffe9->0xff7e,0xffe7->0xff7e" -- LXDE

# explanation (see also TigerVNC manual):
#
# -DisconnectClients -NeverShared:
#     Only allow one connected client at a time.
#
# -nocursor:
#     Since the Screen Sharing app doesn't remove the macOS cursor,
#     disables the cursor within the container.
#
# -geometry ...:
#     Reads RESOLUTION from scripts/display.conf and sets the framebuffer size.
#
# -dpi ...:
#     Derived from SCALE in scripts/display.conf (96 * SCALE). Controls font
#     and cursor scaling in LXDE. Also patched into lxpanel and lxsession
#     configs before the server starts so panel height and icons scale too.
#
# -SecurityTypes VncAuth -PasswordFile /home/user/.vnc/passwd:
#     The connection is unencrypted and the encoded password file
#     is generated from the file called "vncpasswd". You can change it,
#     but the password needs to be 6-8 characters long. This is done so
#     that the Screen Sharing app can be started with the password embedded
#     in the URI. This is by itself insecure, but the Docker container
#     won't allow any inbound traffic other than from the macOS host, so
#     it should be ok. Note that the VNC password does not have to be
#     the same as the user password.
#
# -localhost no:
#     Allows connections from clients other than localhost. This allows
#     macOS to connect to it. Now the exposed VNC server is very insecure
#     but you can only connect to it from the macOS host so even with a
#     disabled firewall, no outside computer could connect to it (see
#     the "docker run" command with the -p option).
#
# -verbose -fg:
#     Display the status of the VNC server and make it such that it stays
#     in the foreground. This makes the Docker container shut down as soon
#     as the X session is quit (using the Logout button in the lower right
#     corner).
#
# -RawKeyboard -RemapKeys "0xffe9->0xff7e,0xffe7->0xff7e":
#     This makes special characters that are typed using the opt-key
#     typeable by reassigning the "Alt_L" and "Meta_L" keys to the
#     "Mode_switch" key.
#
# -- LXDE:
#    Starts an LXDE session.