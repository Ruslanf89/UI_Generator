# UI Forge

A standalone desktop app for designing coordinated HUDs for Godot games. Built
in Godot, with local template generation and editable native Control exports.

![UI Forge desktop](docs/screenshot.png)

## Run

Use **Godot 4.6+** (tested with 4.6.3). Open `project.godot` in Godot and press
**F6** on `scenes/main.tscn`, or **F5** to run the project. The app runs in its
own window; it is not an editor plugin. From a terminal:

```sh
godot --editor --path . --import --quit
godot --path .
```

No package installation, backend, account, network access, or API key is needed.
The desktop requires OpenGL 3.3 support. The minimum window size is 1120 × 900.

For the **portable Windows build**, extract `build/UIForge-windows-x86_64.zip`,
open the `UIForge` folder, and double-click `UIForge.exe`. Keep `UIForge.pck`
beside it. No separate Godot installation is needed to run this package.

## Create a HUD

1. Click **New UI**, or start with the initial FPS design.
2. Choose FPS, RPG, RTS, Racing, Survival, or Platformer. Each genre selects a
   useful starting set of components; change them with the checkboxes.
3. Choose Military, Fantasy, Modern, Horror, Sci-fi, or Minimal.
4. Choose a 16:9 target resolution, then click **Generate 3 variations**.
5. Click a variation's image or name to preview the Balanced, Compact, or
   Cinematic layout. Change the accent color, HUD size, and health/mana values.
6. Click **Export to Godot** and choose a parent directory. A new, uniquely
   named folder is created; existing exports are never overwritten.

Supported components: health, mana, armor, minimap, weapon/ammo, crosshair,
ability slots, objectives, speedometer, laps, resources, and squad/selection.
`Ctrl+G` generates and `Ctrl+E` opens export (`Cmd` on macOS).

Changing the brief requires Generate to apply. Accent, size, health, and mana
update the current design immediately. Export always uses the visible design.
Generate resets customizations to the selected style's defaults. New UI resets
the whole brief. Designs are held in memory; export before closing.

## Use the export in your game

The generated folder contains:

| File | Purpose |
| --- | --- |
| `hud.tscn` | Editable Godot Control scene, with no app scripts |
| `hud_theme.tres` | Shared panel, label, and progress bar styles |
| `preset.json` | Design settings and example values for reference |
| `README.md` | Integration instructions and node paths |

Copy the **whole folder** into your game's project. Instance `hud.tscn` below a
`CanvasLayer`. Enable Editable Children in the Godot editor to adjust individual
controls. The scene uses a transparent, uniformly scaled 1280 × 720 design canvas;
other aspect ratios letterbox the HUD. The target resolution is recorded in the
preset and guide; configure the actual game window size in your game project.

The preview environment is not exported. Minimap geometry, ammo, timers, and
ability slots are examples. Supply your gameplay data and behavior. For example,
with the Health component selected and the exported HUD below `CanvasLayer`:

```gdscript
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Value
@onready var health_text: Label = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Amount

func update_health(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
    health_text.text = "%d / %d" % [current, maximum]
```

This first version generates layouts from curated templates. It does not
generate AI artwork, store editable projects, import exported presets, or supply
game logic. All visuals use native controls; no external artwork is required.

## Validate

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --quit-after 6
```

The test suite covers all 108 genre/style/layout combinations, layout bounds and
overlaps at the supported scale limits, editor interactions, invalid and repeated
exports, and loading a customized export in a separate Godot project. It exits
nonzero on failure. Temporary export fixtures are written to the OS temp directory.
Headless checks do not validate a physical desktop or GPU.

In a cloud shell with a read-only home directory, initialize writable runtime
locations before Godot commands:

```sh
mkdir -p /tmp/ui-generator-godot/{cache,data,config}
export XDG_CACHE_HOME=/tmp/ui-generator-godot/cache
export XDG_DATA_HOME=/tmp/ui-generator-godot/data
export XDG_CONFIG_HOME=/tmp/ui-generator-godot/config
```

## Package a standalone app

Windows x64 is the primary downloadable target. To create its portable
development ZIP with Python 3.10+ and Godot 4.6.3:

```sh
python3 scripts/package_windows.py
```

The script downloads the official Godot Windows engine over HTTPS, verifies
its pinned published SHA-512 checksum, exports the app with Windows settings,
and creates `build/UIForge-windows-x86_64.zip`. The ZIP includes the executable,
companion PCK, instructions, SHA-256 checksums, and engine license notices.
It uses the full engine; a production export with official templates is smaller.
Packaging, archive integrity, and the resource pack are checked on Linux;
execution on Windows remains unvalidated. Rebuild after changing the app.

To use an existing official runtime archive or a custom local Godot executable:

```sh
python3 scripts/package_windows.py --runtime-zip /path/to/Godot_v4.6.3-stable_win64.exe.zip --godot /path/to/godot
```

Export presets are included for Linux x86_64 and Windows x86_64. Install the
matching official Godot export templates through **Editor → Manage Export
Templates**, then use **Project → Export** or:

```sh
mkdir -p build
godot --headless --path . --export-release Linux build/UIForge.x86_64
godot --headless --path . --export-release Windows build/UIForge.exe
```

Windows packaging is configured but has not been validated on Windows. For
macOS, add a macOS preset in Godot and configure signing for distribution.

A standalone Linux **development** package can also use the installed Godot
executable without downloading export templates:

```sh
bash scripts/package_linux.sh
```

This creates `build/UIForge-linux-x86_64.tar.gz`. Extract it and run
`linux/UIForge.x86_64`. Keep the `.pck` beside the executable. This bundle includes
the full Godot engine and its license notices; a template-based release is smaller.
Build outputs are ignored by Git. Godot engine notices are in `licenses/godot`.
