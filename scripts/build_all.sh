#!/usr/bin/env bash
# Builds Web (single-threaded, GitHub Pages friendly) and Windows x86_64 exports.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import >/dev/null 2>&1 || true
mkdir -p builds/web builds/windows
"$GODOT" --headless --export-release "Web" builds/web/index.html
"$GODOT" --headless --export-release "Windows Desktop" builds/windows/MarginCall.exe
python3 -c "import zipfile; z=zipfile.ZipFile('builds/MarginCall-windows-x86_64.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9); z.write('builds/windows/MarginCall.exe','MarginCall/MarginCall.exe'); z.close()"
ls -la builds/web builds/MarginCall-windows-x86_64.zip
