#!/usr/bin/env bash
# Produce a standalone Linux development build using the installed Godot binary.
# For a smaller release build, use Godot's official export templates instead.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_binary=${GODOT_BIN:-$(command -v godot)}
destination="$repo_root/build/linux"
mkdir -p "$destination"

"$godot_binary" --headless --path "$repo_root" --export-pack Linux "$destination/UIForge.pck"
cp -- "$(realpath -- "$godot_binary")" "$destination/UIForge.x86_64"
chmod +x "$destination/UIForge.x86_64"
cp -- "$repo_root/licenses/godot/LICENSE.txt" "$destination/GODOT_LICENSE.txt"
cp -- "$repo_root/licenses/godot/COPYRIGHT.txt" "$destination/GODOT_COPYRIGHT.txt"
cat > "$destination/README.txt" <<'INSTRUCTIONS'
UI Forge — Linux x86_64 standalone development build

Extract the whole folder, then run ./UIForge.x86_64 (or double-click it).
Keep UIForge.pck beside the executable. No separate Godot installation is needed.
Requires a Linux desktop with OpenGL 3.3 support and standard X11/Wayland libraries.
This development package includes the full Godot engine, so it is larger than
a release made with the official Godot export templates.

Choose a genre, style, and components, then generate three variations.
Click a variation to select it. Customize the accent and HUD size on the right.
Export to Godot creates a new folder containing hud.tscn, hud_theme.tres,
preset.json, and a guide for wiring the controls to your game.
Copy that entire folder into a Godot 4.6+ project and instance hud.tscn.
Generated maps, values, timers, and abilities contain sample data.

Generation uses local templates. No AI service, account, or API key is required.

The bundled Godot engine is licensed under MIT; see GODOT_LICENSE.txt and
GODOT_COPYRIGHT.txt for the engine and third-party notices.
INSTRUCTIONS

tar -czf "$repo_root/build/UIForge-linux-x86_64.tar.gz" -C "$repo_root/build" linux
printf 'Standalone build: %s\n' "$repo_root/build/UIForge-linux-x86_64.tar.gz"
