#!/bin/zsh

# Creates a Vivado.app launcher in /Applications that opens a Terminal
# window and runs start_container.sh.

script_dir=$(dirname -- "$(readlink -nf $0)")
source "$script_dir/header.sh"
validate_macos

APP="/Applications/Vivado.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Convert the Vivado PNG logo to an .icns file using macOS built-in tools.
# The PNG is in the Xilinx installation tree; find it via glob so it works
# across Vivado versions.
icon_png=$(echo "$script_dir"/../Xilinx/*/Vivado/doc/images/vivado_logo.png(N[1]))
if [[ -f "$icon_png" ]]; then
    iconset=$(mktemp -d).iconset
    mkdir -p "$iconset"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$icon_png" --out "$iconset/icon_${size}x${size}.png"    > /dev/null 2>&1
        sips -z $((size*2)) $((size*2)) "$icon_png" --out "$iconset/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    iconutil -c icns "$iconset" -o "$APP/Contents/Resources/Vivado.icns" 2>/dev/null
    rm -rf "$iconset"
fi

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Vivado</string>
    <key>CFBundleIconFile</key>
    <string>Vivado</string>
    <key>CFBundleIdentifier</key>
    <string>com.vivado.launcher</string>
    <key>CFBundleName</key>
    <string>Vivado</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

cat > "$APP/Contents/MacOS/Vivado" << EOF
#!/bin/bash
osascript -e 'tell application "Terminal"
    activate
    do script "$script_dir/start_container.sh"
end tell'
EOF

chmod +x "$APP/Contents/MacOS/Vivado"

f_echo "Created $APP"
