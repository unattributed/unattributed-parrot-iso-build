#!/bin/bash
set -e

cd ~/workspace/unattributed-parrot-iso-build

echo "[INFO] Cleaning up auto/config..."

# 1. Remove any file (from Git index and disk)
if git ls-files --error-unmatch auto/config &>/dev/null; then
  git rm -r --cached auto/config
  echo "[INFO] Removed auto/config from Git index"
fi

rm -rf auto/config 2>/dev/null || true

# 2. Recreate as a directory
mkdir -p auto/config

# 3. Add an executable stub (optional)
cat <<'EOF' > auto/config/01-custom-options
#!/bin/bash
# Optional: add live-build overrides here
EOF

chmod +x auto/config/01-custom-options

echo "[INFO] Final directory listing:"
ls -l auto/config

echo "[INFO] Commit this directory with:"
echo "  git add auto/config/01-custom-options"
echo "  git commit -m 'Fix auto/config script dir for live-build compliance'"
