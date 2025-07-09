#!/bin/bash
set -e

CONFIG_FILE="auto/config"

echo "[+] Removing incorrect auto/config directory if it exists..."
[ -d "$CONFIG_FILE" ] && rm -rf "$CONFIG_FILE"

echo "[+] Recreating auto/config as an executable file..."
cat <<'EOF' > "$CONFIG_FILE"
#!/bin/bash
# Optional: Custom live-build config steps can be added here
EOF

chmod +x "$CONFIG_FILE"

echo "[+] Done. Confirming:"
ls -l "$CONFIG_FILE"
file "$CONFIG_FILE"
