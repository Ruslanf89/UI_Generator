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
godot --headless --path . --script tests/run_kit_tests.gd
godot --headless --path . --script tests/run_kit_shape_tests.gd
godot --headless --path . --script tests/run_ai_tests.gd
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

The fantasy kit suite is separate from the original HUD regression suite. Run
both after changing shared preview or app behavior. It checks the three kit art
styles, native controls and button states, repeatable procedural artwork,
individual component regeneration, and portable three-scene exports. Kit
exports must retain each page's custom transforms and load in a separate game
project with all PNGs imported. Visual inspection is still needed for text
readability, ornament placement, and the pixel grid at different window sizes.

The shape suite also exports orbs and vials into independent Godot projects.
To verify actual minimap clipping and liquid fill rendering with a display, run:

```sh
godot --path . --rendering-driver opengl3 --audio-driver Dummy --script tests/run_kit_shape_tests.gd -- --render
```

The local AI suite uses a simulated ComfyUI HTTP server. It exercises connection
and checkpoint discovery, workflow submission, queued-job polling, image
download, errors, cancellation, and the app's accepted-artwork behavior. These
checks do not load SDXL or measure real NVIDIA GPU performance. Real inference,
RTX 5060/CUDA compatibility on the user's PC, image quality, and background
removal quality still require the manual test in the
[local AI guide](local-ai-guide.md). No image-quality claim should be based on
the HTTP fixture.

In a cloud shell with a read-only home directory, initialize writable runtime
locations before Godot commands:

```sh
mkdir -p /tmp/ui-generator-godot/{cache,data,config}
export XDG_CACHE_HOME=/tmp/ui-generator-godot/cache
export XDG_DATA_HOME=/tmp/ui-generator-godot/data
export XDG_CONFIG_HOME=/tmp/ui-generator-godot/config
```

## Work on the designer and generators

The designer window is constructed by `scripts/app.gd` at runtime; the main
scene contains its root Control. See
[Edit the UI Forge designer itself](godot-guide.md#edit-the-ui-forge-designer-itself)
for the editor workflow and a source-file map.

Fantasy kit generation is split between `scripts/kit_generator.gd` (native
controls and the Menu/HUD/Components pages), `scripts/kit_art.gd` (seeded
procedural images), and `scripts/kit_exporter.gd` (portable scenes, theme, and
PNGs). Preserve component identifiers when sharing artwork across pages: a
component seed override should change that component everywhere it appears,
while leaving other artwork and all transforms intact.

`scripts/kit_design.gd` supplies the shared seeded recipe for the design language,
frame geometry and motifs, icon/fill variants, and menu/HUD composition. Preserve
determinism when extending the generator: the same seed and brief should
rebuild the same procedural design, independent of cache state. Keep component
regeneration isolated from the shared recipe and page transforms so refining
one piece does not reroll the rest of the kit.

`scripts/kit_art.gd` delegates detailed frame geometry and ornaments to
`scripts/kit_frame_art.gd`, and icon drawing to `scripts/kit_icon_art.gd`.
`scripts/kit_motif_art.gd` assembles the original vector drawings bundled under
`assets/ornaments/` with generated relief, borders, and placement.
`scripts/kit_shapes.gd` shares map-window masks and resource-reservoir geometry
between the artwork and native controls. Keep these helpers coordinated through
the shared recipe when adding variants.

When changing recipe or composition code, check all three art styles, all ten
design languages, and all four menu/HUD compositions. Include the six map shapes
and four resource forms: map children must stay clipped to the actual aperture,
and every resource form must respond to live Range `value`/`max_value` changes.
Compare a rebuilt seed after clearing artwork caches, and verify that an individual reroll leaves
other images and page transforms unchanged. The **Keep seed** workflow should
reproduce the initial generated design; full generation still clears custom
arrangements and component overrides.

**Surprise everything** rolls the complete brief from the seed, while manual
mode uses the selected art style, language, material, decoration, map shape,
and resource form. A kept seed must reproduce the surprise brief as well as its
artwork and layout. Export and standalone-package checks must include the
bundled vector assets and generated clipping-mask textures.

The default kit combines bundled original artwork with procedural drawing and
assembly, without model inference. Optional prompt generation uses
`scripts/comfy_client.gd` for the local ComfyUI API,
`scripts/ai_pipeline.gd` for coordinated requests, and `scripts/ai_art.gd` for
artwork preparation and integration. The app does not download models or launch
ComfyUI. The supported workflow uses built-in SDXL nodes and batch size 1;
models and runtime dependencies are installed separately by the user.

Keep the local endpoint restricted to loopback addresses. A failed or cancelled
batch must preserve the current accepted kit, and cancelling UI Forge's wait
must not interrupt unrelated ComfyUI jobs. Undo/redo should reuse accepted image
data rather than queueing another model inference. The prompt, endpoint, and
model preferences are local app settings, separate from generated designs.

Keep export scenes independent of generator scripts, ComfyUI, and model files.
Button state textures and textures inside StyleBoxTexture resources must be
included under `art/`, even when they are not visible in a normal-state preview.
Copying an AI export into a separate Godot project must preserve its PNGs and
editable controls without a running local model.

## Package a standalone app

Windows x64 is the primary downloadable target. To create its portable
development ZIP with Python 3.10+ and Godot 4.6.3:

```sh
python3 scripts/package_windows.py
```

The script downloads the official Godot Windows engine over HTTPS, verifies
its pinned published SHA-512 checksum, exports the app with Windows settings,
and creates `build/UIForge-windows-x86_64.zip`. The ZIP includes the executable,
companion PCK, end-user Windows/Godot/local-AI guides, a health-bar example, SHA-256
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
