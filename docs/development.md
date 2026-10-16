# Development and packaging

These instructions are for contributors who want to test or build UI Forge.
End users should start with the [Windows guide](windows-guide.md) or the
[Godot guide](godot-guide.md). First download or clone the source project;
the portable app ZIP does not contain the full source. Run commands from the
repository root
(the folder containing `project.godot`).

## Validate

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --quit-after 6
```

The test suite covers all 108 genre/style/layout combinations, layout bounds and
overlaps at the supported scale limits, editor interactions, invalid and repeated
exports, loading a customized export in a separate Godot project, and the
documented Space-to-damage / R-to-heal example. It exits
nonzero on failure. Temporary export fixtures are written to the OS temp directory.
Headless checks do not validate a physical desktop or GPU.

The suite also injects viewport mouse/key events for dragging, clamping,
snapping, variant isolation, nudging, and undo/redo; rasterizes every artwork
style/detail combination; checks all seven materials, seed reproducibility after
cache eviction, texture size/wear changes, and live inspector updates; and imports
a moved, textured HUD into an independent game project. Exported PNG pixels are
compared with the preview. Generated material PNGs use relative paths and need Godot's normal
image import before running a copied scene.

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
companion PCK, end-user Windows/Godot guides, a health-bar example, SHA-256
checksums, and engine license notices.
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
