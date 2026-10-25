# Windows user guide

This guide takes you from downloading UI Forge to exporting a HUD or a matching
fantasy UI kit. You do not need programming knowledge to design and export.
Connecting the controls to a running game is covered in the
[Godot guide](godot-guide.md).

[Back to the project home page](../README.md)

## 1. Choose the right download

| Download | What you receive | How you open it |
| --- | --- | --- |
| `UIForge-windows-x86_64.zip` in a release's **Assets** | The packaged desktop app | Extract it, then double-click `UIForge.exe` |
| **Code → Download ZIP** or **Source code (zip)** | The Godot source project | Import `project.godot` into Godot, then press F5 |

For the packaged app, open
[UI Forge Releases](https://github.com/Ruslanf89/UI_Generator/releases).
Choose a release that includes `UIForge-windows-x86_64.zip` under **Assets**.
Prereleases are development previews. If no Windows ZIP is listed, follow
[Run UI Forge from source](godot-guide.md#run-ui-forge-from-source).

The packaged app targets **Windows x64** and requires **OpenGL 3.3-compatible
graphics**. Its smallest window is **1120 × 900**. The runtime is included;
installing Godot, Python, Git, or export templates is unnecessary for this route.
Internet access is needed for downloading, but generation runs locally.

## 2. Extract the app

1. Wait for `UIForge-windows-x86_64.zip` to finish downloading.
2. Open **File Explorer → Downloads** and locate that ZIP.
3. Right-click it and choose **Extract All…**.
4. Choose a writable destination, for example
   `C:\Users\YourName\Documents\UIForgeApp`, and click **Extract**.
   Replace `YourName` with your Windows account name.
5. Open the extracted folder and then the **UIForge** folder inside it.

You should see these files, along with the documentation and license notices:

```text
UIForge/
  UIForge.exe
  UIForge.pck
  README.txt
  docs/
    windows-guide.md
    godot-guide.md
    examples/
      health_demo.gd
```

Run the app from the **extracted folder**. Opening the executable while browsing
inside the ZIP may leave its companion files unavailable.

## 3. Open the app

1. Double-click **UIForge.exe**.
2. Leave **UIForge.pck** in the same folder. It contains the app's scenes,
   scripts, and visual resources.
3. Wait for the **UI FORGE** window. It opens with an FPS/Military design and
   three variations already generated.

There is no installer or sign-in screen. To create a desktop shortcut,
right-click `UIForge.exe` and use **Show more options → Send to → Desktop
(create shortcut)**. The shortcut should point to the executable in its
extracted folder. Keep the whole app folder together when moving it.

## 4. Understand the window

![The UI Forge window](screenshot.png)

| Area | What it controls |
| --- | --- |
| Mode dropdown at the top of **Design Brief** | Choose **HUD layouts** or **Fantasy UI kit** |
| **Design Brief**, on the left | HUD choices, or kit surprise/manual controls, map/resource shapes, and seed; target resolution and Generate |
| Large central preview | The selected layout or kit page over an illustrative background; select, move, and resize pieces here |
| Three thumbnails below the preview | HUD layout options, or the kit's Menu, HUD, and Components pages |
| **The Finishing Touches**, on the right | Accent color, HUD size, and example health/mana values |
| **Arrange Elements**, in the right panel | Selected component coordinates, grid snapping, and layout reset |
| **Offline Material Art**, in the right panel | Surface material, frame detail, texture size, wear, opacity, and seed |
| **Refine One Piece**, in the right panel | **Regenerate selected** changes one kit component's artwork |
| **Local AI Art**, in the right panel | **Open AI studio** opens the prompt/model dialog for local ComfyUI generation |
| **New UI**, at the top | Resets the brief and customizations to the initial FPS/Military design |
| **Export to Godot**, at the top | Saves the selected HUD layout, or all three kit pages, into a new folder |
| Status line, at the bottom | Generation messages, export location, and errors |

## 5. Create a first FPS HUD

1. Click **New UI** to start with the default design. Export any design you
   want to keep before resetting it.
2. Keep **HUD layouts** selected, then under **01 Game Type**, select **FPS**.
3. Under **02 Visual Style**, click **Military**.
4. Under **03 Components**, keep Health bar, Armor bar, Minimap, Weapon & ammo,
   Crosshair, and Objective tracker selected. Scroll inside this list to find
   the lower options. Untick components you do not want.
5. Leave **Target Resolution** at **1920 × 1080 / Full HD**.
6. Click **Generate 3 variations**.
7. Click **01 Vanguard**, **02 Recon**, or **03 Sentinel** below the thumbnails
   to compare the layouts. Clicking a thumbnail also selects that variation.
8. Choose the variation you prefer. The large preview shows the design that
   will be exported.

Other genres select different starting components. For example, choose **RPG**
to start with health, mana, minimap, abilities, and objectives. Component choices
remain editable for every genre. At least one component must be selected.

## 6. Customize the selected design

1. Click the color swatch under **Accent Color** and choose a color.
2. Move **HUD Size** to change component sizes between 85% and 110%.
3. If Health bar is included, move the **Health** slider to see it change.
4. If Mana bar is included, move the **Mana** slider to see it change.
   A faded slider means that component is not in the generated HUD.

Accent, size, health, and mana changes appear immediately and carry into the
export. They apply to all three generated HUD variations, or all three pages
when working on a fantasy kit.

### Move components with your mouse

1. Click a component in the **large central preview**, such as the health bar.
   A green outline shows the selection; its design-canvas X/Y coordinates appear
   under **Arrange Elements** on the right.
2. Hold the left mouse button, drag the component, and release to keep its position.
   The component stays inside the 1280 × 720 design canvas.
3. Enable **Snap to 8 px grid** for aligned mouse placement.
4. After selecting a component, use the **arrow keys** to move it 1 design pixel,
   or **Shift+arrow** for 10 pixels.
5. Use **Ctrl+Z** to undo a position edit; **Ctrl+Shift+Z** or **Ctrl+Y** redoes it.
6. Click **Reset this layout** to return the current variation's components to
   their preset positions and sizes. This reset can also be undone.

### Rescale a component with your mouse

1. Click a component in the large preview to select it.
2. Hover over one of its four green corner handles. The cursor changes to a
   diagonal resize arrow.
3. Hold the left mouse button and drag the corner outward to enlarge the
   component, or inward to shrink it.
4. Release to keep the size. Text, bars, icons, and artwork scale together,
   preserving the component's proportions. The opposite corner stays fixed.
5. Read the selected component's percentage under **Arrange Elements**.
6. Press **Ctrl+Z** to undo the resize, or **Ctrl+Shift+Z** / **Ctrl+Y** to redo.
   Press **Esc** during a move or resize to cancel that unfinished gesture.

Individual scales range from 35% to 300% of the preset size. Canvas edges may
limit enlargement; move the component away from an edge for more room. With
**Snap to 8 px grid**, resizing snaps the width while preserving proportions.
The **HUD Size** slider scales the overall design on top of individual scales.

Positions are stored separately for Balanced, Compact, and Cinematic, or for
each kit page. Switching previews keeps their edits. Changing color or frame artwork keeps custom
positions and scales; the exported scene uses the same arrangement. Thumbnails
select variations; dragging is enabled in the large preview.

### Generate textured artwork offline

These controls belong to **HUD layouts** mode. Fantasy kits generate their
artwork automatically with the simple controls described below.

1. Scroll the right-hand panel to **Offline Material Art**.
2. Choose a **Material**: brushed metal, leather, stone, wood, glass, carbon
   fiber, or parchment. **Style native** selects a suitable material automatically:
   metal for Military, leather for Fantasy, stone for Horror, glass for Modern
   and Minimal, and carbon fiber for Sci-fi.
3. Choose a separate **Frame detail**: Style native, Ornate, Tech, Weathered,
   or Clean. Try Leather + Ornate for Fantasy, or Carbon fiber + Tech for Sci-fi.
4. Click **Generate art**. Textured panels appear in all three variations.
5. Adjust **Texture size** (50–200%) for finer or larger grain, **Wear** for
   additional edge chips and scratches, and **Art opacity** for subtler or stronger
   surfaces. Material controls update existing artwork automatically after a short
   pause. Text and gameplay bars remain independently editable.
6. Click **New** beside **Seed** to generate a fresh pattern. To reproduce a
   design, enter the same integer seed and use the same material, frame, size,
   wear, accent, visual style, and layout. Components receive coordinated but
   distinct patterns. **Generate art** uses the displayed seed.
7. Change the accent color to recolor the frame. Click **Clear** to remove all
   artwork while keeping your custom positions and scales.

![Procedural material examples](materials.png)

Artwork is generated procedurally on your PC, without an AI service, account,
or API key. It decorates panel components; the crosshair keeps its native shapes.
Exports include a separate PNG for each panel at twice its base dimensions,
and `preset.json` records the material settings and seed. Copy the `art/` folder
with the scene. In HUD layouts mode, undo/redo applies to moving and resizing;
it does not undo material-art changes. Kit component regeneration also supports
undo, as described below. Export your design before starting another one.

Changing game type, style, components, or resolution leaves a **Changes pending**
message. Click **Generate** to apply those changes. Generate resets accent,
size, sample values, component positions/scales, and artwork to defaults, so
refine those settings after generation. HUD export uses the selected layout.
Kit export saves all three generated pages.

Keyboard shortcuts: **Ctrl+G** generates; **Ctrl+E** opens export.

## Create a fantasy UI kit

Use this mode to generate a menu, gameplay HUD, and reusable components with
matching shapes, materials, colors, and ornaments.

1. Export any current work you want to keep.
2. At the top of the left **Design Brief** panel, change **HUD layouts** to
   **Fantasy UI kit**.
3. Leave **Surprise everything** checked. This is the default. Choose **Target
   Resolution** and leave **Keep seed** unchecked for fresh results.
4. Click **Generate complete kit**. The seed chooses an art style, design
   language, material, layout, map shape, and resource form, with **Rich**
   decoration. A compact summary shows the rolled result.
5. Click **Menu**, **HUD**, and **Components** below the previews to inspect
   the three pages. These are parts of one kit, rather than alternative layouts.

![Fantasy kits with coordinated artwork](fantasy-kits.png)

| Page | Included examples |
| --- | --- |
| **Menu** | Title banner, menu panel, Continue/New journey/Settings/Exit buttons, character panel, and quest card |
| **HUD** | Health/mana resource displays, currency, shaped minimap sample, objective panel, ability buttons, and quest-log button |
| **Components** | Framed panel, button-state examples, inventory slots, health/mana bars, and procedural icons |

The kit combines original bundled vector drawings with procedural frames,
surfaces, and assembly. It runs offline without a separate model. You can also
generate images from a prompt using local ComfyUI and SDXL, as described below.
The controls and sample screens form a starting kit; the app does not create
gameplay logic.

### Choose your own look and shapes

Uncheck **Surprise everything** to reveal the manual pickers. While surprise is
on, those pickers are hidden and the summary shows the current rolled choices.
After changing manual choices, click **Generate complete kit** to apply them.

| Control | Choices |
| --- | --- |
| **Art Style** | **Illustrated fantasy** for layered illustrated shapes, **Medieval pixel** for a crisp pixel grid, or **Sculpted fantasy** for stronger relief and embossed shading |
| **Design language** | A theme from the table below, or **Surprise me** to select it from the seed |
| **Material** | **Wood**, **Stone**, or **Parchment** |
| **Decoration** | **Simple**, **Balanced**, or **Rich** |
| **Map shape** | **Surprise me**, **Circle**, **Hexagon**, **Shield**, **Octagon**, **Diamond**, or **Square** |
| **Resource form** | **Surprise me**, **Bar**, **Orb**, **Vial**, or **Segmented** |

The design languages coordinate a set of original vector motifs:

| Design language | Motif |
| --- | --- |
| Royal court | Griffin |
| Wildwood | Stag |
| Runic forge | Golem |
| Astral order | Celestial crest |
| Dragon covenant | Dragon |
| Moonfang clan | Wolf |
| Raven court | Raven |
| Sun temple | Sun |
| Bone crypt | Skull |
| Tidal shrine | Kraken |

The app assembles these bundled drawings locally with seeded borders, shading,
and ornaments. They are original vector parts; no AI service is used for this
built-in artwork.

Maps now have larger shaped windows. The sample map content is clipped to the
actual circle, shield, or other chosen outline. Health and mana remain live
controls in every form: move the **Health**/**Mana** sliders to test bars,
segmented fills, or filling/emptying orbs and vials. Their exported values can
be driven by your game code.

### Explore different offline designs

The generator uses one seeded design recipe to coordinate frame silhouettes,
corner shapes, vector motifs, icons, map windows, and health/mana displays.
The chosen design language guides this recipe across buttons, panels, and HUD pieces. Generation
also selects among four menu/HUD compositions, changing grouping and placement
as well as the artwork: **Split court**, **Story sidebar**, **Command grid**,
and **Ribbon hall**. Any design language can use any of these compositions.
The seed also varies panel proportions, button spacing, and HUD dimensions
within a composition, so each layout type can produce many different designs.

![Offline design languages and artwork](procedural-designs.png)

With **Keep seed** unchecked, click **Generate complete kit** to get a fresh
seed. **Surprise everything** can change the whole brief; with it off, your
manual choices guide the new result. The **Menu**,
**HUD**, and **Components** cards show pages of that result; they are not three
alternative complete kits. Use **Regenerate selected** when you want new
artwork for one piece while keeping the current layout and other artwork.

With **Surprise everything** on and **Keep seed** off, a new generation changes
the art style, dominant motif, map outline, resource form, and composition from
the immediately previous kit. In manual mode, explicitly chosen map and
resource forms stay fixed; **Surprise me** lets the seed choose them.

To reproduce a starting design:

1. Note the **Design seed** shown after generating a kit. Keep **Surprise
   everything** in the same state. For a manual design, keep the same art style,
   design language, material, decoration, map shape, resource form, and resolution.
2. Enter that number under **Design seed**. Editing it automatically checks **Keep seed**.
   You can also tick **Keep seed** to reuse the seed already displayed.
3. Click **Generate complete kit**. The same seed and brief recreate the same
   initial artwork and layout. **Surprise everything** also reproduces its
   rolled art style, theme, material, and shapes from that seed.
4. Uncheck **Keep seed** when you want to explore fresh complete designs again.

Keeping a seed does not keep your custom mouse arrangement or later individual
regenerations when you generate the whole kit again. Full generation starts
from the generated layout and clears those edits, as well as accepted AI art.
Export the current result to preserve it. **Regenerate selected** can still
vary one piece while the main kit seed is kept.

The built-in generator needs no ComfyUI installation, model download, provider
account, or text prompt. Its controls describe a procedural design; the
separate AI studio is optional.

### Refine one piece without replacing the kit

1. Open the page containing the piece you want to change.
2. Click it in the **large preview**. Its outline turns green and the right
   inspector shows its name. You select a whole component: for example,
   **Inventory** includes its slots and icons, and **Health** includes its frame,
   emblem, and bar artwork.
3. Under **Refine One Piece**, click **Regenerate selected**.
4. Inspect the new details. Click again for another result, or press **Ctrl+Z**
   to restore the previous artwork. **Ctrl+Shift+Z** or **Ctrl+Y** redoes it.

Offline regeneration changes that component's shapes, frame structure, and
ornaments, including its related states and icons. Other components keep their
artwork, and all pages keep their positions and sizes. A component used on
multiple pages, such as **Health**
or **TitleBanner**, receives the change on each of those pages.

Drag pieces and use their corner handles as described above. **Accent Color**,
**HUD Size**, and the live **Health**/**Mana** sliders work for kits too.
**Offline Material Art** is hidden in kit mode; the material and decoration
choices on the left supply the built-in kit artwork. The accent picker is
disabled while AI images are active; their colors come from the artwork prompt.

Changing the kit style, design language, material, decoration, map shape,
resource form, or resolution
marks the brief as pending. **Generate complete kit** applies it by creating a fresh entire kit
and resetting the current arrangement, color, sizes, and sample values. Export
first if you want to keep the previous result. **Regenerate selected** is the
way to change one piece while preserving the current kit.

Buttons in the designer are selected and arranged with the mouse. Their game
actions become available after export, when you connect their native signals
in Godot. The **Components** page displays examples of the button states.
Built-in pixel artwork uses nearest filtering. Fractional viewport scaling can make
pixel widths uneven; use whole-number game scaling for the sharpest pixel grid.

### Generate images from a prompt with local AI

For this route, first follow **[Local AI artwork on Windows](local-ai-guide.md)**.
It explains the current NVIDIA portable runtime, SDXL checkpoint download,
RTX 5060 8 GB setup, and a single-image ComfyUI test. You need no provider key
or image API subscription. The model runs on your PC; the initial downloads
and storage are separate from the UI Forge app.

1. Start ComfyUI with **run_nvidia_gpu.bat** and keep its command window open.
   Confirm that **http://127.0.0.1:8188** works in your browser.
2. In UI Forge, generate a **Fantasy UI kit** and scroll the inspector to
   **Local AI Art → Open AI studio**.
3. In the studio dialog, leave the local address at
   **http://127.0.0.1:8188**, then click **Connect & load models**.
4. Choose your installed **sd_xl_base_1.0.safetensors** checkpoint.
5. Describe the artwork in the prompt box: colors, materials, silhouettes,
   trim, and visual treatment. Click **Generate AI artwork**.
6. Wait for the complete batch. UI Forge generates the different art roles
   one image at a time; the first full kit can take several minutes.
7. Review all three pages. **Regenerate selected** now calls the model for
   only the selected component's art roles. Undo restores the accepted images.
8. Choose **Use procedural art** to return to the built-in artwork, or export
   the AI kit when you like the result.

Your current kit remains intact until the requested batch succeeds. **Cancel**
keeps the accepted kit and stops further submissions; an image already running
in ComfyUI may still finish. UI Forge does not interrupt other ComfyUI jobs.

The model supplies images; Labels, button text, resource values, and the layout
stay editable. Matte removal can leave edge defects, and separately generated
pieces can vary. Adjust the prompt and retry as needed. Avoid magenta subject
details because the workflow uses a magenta background for removal. AI images
keep their generated colors, so edit the prompt and regenerate to change the
palette. The built-in style selection does not guarantee a model will produce
a strict pixel grid.

Export before closing the app or starting a new complete kit. The local server,
model, and prompt preferences are remembered; generated designs cannot yet be
reopened. Your exported game needs the scenes/theme/PNGs, without ComfyUI or SDXL.

## 7. Export your HUD or kit

1. In File Explorer, create a folder such as
   `C:\Users\YourName\Documents\UIForgeExports`.
2. In UI Forge, select the HUD variation you want to use. For a kit, any page
   can be selected: **all three pages will be exported**.
3. Click **Export to Godot**.
4. In the folder chooser, navigate to `Documents\UIForgeExports` and select
   that folder as the destination. The destination must already exist.
5. Wait for the export-success dialog. It shows the full output path.
6. Open that path in File Explorer.

For the FPS/Military/Balanced example, the app creates a folder like this:

```text
UIForgeExports/
  uiforge_fps_military_balanced/
    hud.tscn
    hud_theme.tres
    preset.json
    README.md
    art/                         # present when frame artwork was generated
      health.png
      ...other panel frames...
```

Repeated exports create new folders with suffixes such as `_2`; they do not
overwrite previous exports.

| Exported file | How you use it |
| --- | --- |
| `hud.tscn` | The HUD scene you add to your game in Godot |
| `hud_theme.tres` | Shared styling; keep it beside `hud.tscn` |
| `preset.json` | A record of your design choices and sample values |
| `README.md` | Instructions included with this particular HUD |
| `art/` (optional) | Generated PNG frames referenced by the scene; copy this folder too |

Continue with [Add an exported HUD to your game](godot-guide.md#add-an-exported-hud-to-your-game).

### Fantasy kit export

A kit creates a folder such as this:

```text
UIForgeExports/
  uiforge_kit_illustrated_fantasy/
    menu.tscn
    hud.tscn
    components.tscn
    kit_theme.tres
    preset.json
    README.md
    art/
      ...generated frame, state, fill, and icon PNGs...
```

Keep the **whole folder** together. `menu.tscn` is the menu example,
`hud.tscn` is the gameplay overlay, and `components.tscn` is a collection of
matching reusable controls. They share `kit_theme.tres` and use images in
`art/`. Some button images appear only on hover, focus, or press, so keep all
of them. `preset.json` records the design language, settings, positions, sizes,
and seed information. AI exports also include their accepted generated PNGs; those
images are the artwork your game uses. The preset cannot yet be reopened in
UI Forge.

Continue with [Add an exported fantasy kit to your game](godot-guide.md#add-an-exported-fantasy-kit-to-your-game).

## 8. Keep your work

Export before closing the app, generating another design, or clicking **New UI**.
Designs are currently held in memory, and reopening exported presets in UI Forge
is not implemented.
You can keep editing the exported scene and theme directly in Godot.

The menus, minimap, weapon values, timers, inventory, and ability slots contain
example data. They become functional when connected to your game's code. The
central preview background is illustrative and is not exported. HUD layouts use
local templates; fantasy kits combine bundled original vector parts, procedural
drawing, and seeded composition rules.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| No `UIForge.exe` in the download | You may have downloaded the source ZIP. Follow the Godot source-project guide, or choose the Windows app ZIP under a release's Assets. |
| Godot Project Manager appears instead of UI Forge | Extract the complete app ZIP again and keep the matching `UIForge.exe` and `UIForge.pck` together. |
| A missing resource/pack error, or the app closes immediately | Run from the extracted folder, confirm the PCK exists, and extract a fresh complete copy if a file is missing. |
| A graphics/OpenGL error | Check that the PC supports OpenGL 3.3 and install the graphics driver supplied by the GPU or PC manufacturer. |
| Bottom controls are off screen | Maximize the app. Windows display resolution and scaling must leave enough room for the 1120 × 900 minimum window. Check **Settings → System → Display**. |
| Mana or health slider is faded | Select that component on the left and click Generate. |
| Changing style does not change the preview | Click Generate to apply the pending brief. |
| Dragging a thumbnail does not move a component | Choose a variation, then drag its component in the large central preview. |
| Artwork or arrangement controls are missing | Scroll inside the right-hand inspector panel. |
| Art generation says it needs a panel | Include Health, Minimap, Weapon, or another panel component. The crosshair is made of native shapes. |
| Regenerate selected is disabled | Generate a fantasy kit, then select a piece in the large preview. |
| Kit material/style changes are not visible | Click **Generate complete kit** to apply the pending brief. Export the current kit first if you want to keep it. |
| Generate keeps recreating the same offline kit | Uncheck **Keep seed** to get a fresh seed and another composition. |
| The same seed does not restore my dragged positions | Seeds reproduce the initial procedural kit. Export before full generation to preserve mouse edits and individual regenerations. |
| A kit exports pages you were not viewing | This is expected: every kit export includes Menu, HUD, and Components. |
| Menu buttons do not start a game | Export the kit, add the menu to your game, and connect its Button signals to your game code. |
| Local AI cannot connect, or generation fails | Follow the [local AI troubleshooting guide](local-ai-guide.md#troubleshooting-an-rtx-5060-8-gb-setup); test a single SDXL image in ComfyUI first. |
| Accent color is disabled | AI artwork retains its generated colors. Change the prompt and generate new artwork, or choose **Use procedural art**. |
| Export fails | Choose an existing writable folder, such as a folder in Documents. Read the status line for the specific error. |
| Map or ammo is not changing in a game | Those are sample controls; follow the Godot integration guide and connect gameplay data. |

To report a problem, open a
[GitHub issue](https://github.com/Ruslanf89/UI_Generator/issues) with your Windows
version, app version or download filename, exact error text, and steps that
caused it. Packaging was checked on Linux; native Windows launch has not yet
been validated in this project.
