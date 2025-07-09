#!/bin/bash
set -e

echo "[INFO] Removing incorrect auto/config file if it exists..."
if [ -f auto/config ]; then
  rm -f auto/config
fi

echo "[INFO] Recreating auto/config as a directory..."
mkdir -p auto/config

echo "[INFO] Adding default executable stub to auto/config/01-custom-options"
cat <<'EOF' > auto/config/01-custom-options
#!/bin/bash
# Optional build flags for live-build
EOF

chmod +x auto/config/01-custom-options

echo "[INFO] Final structure:"
ls -l auto/config
