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
| **Design Brief**, on the left | HUD game type/style/components, or kit art style/material/decoration; target resolution and Generate |
| Large central preview | The selected layout or kit page over an illustrative background; select, move, and resize pieces here |
| Three thumbnails below the preview | HUD layout options, or the kit's Menu, HUD, and Components pages |
| **The Finishing Touches**, on the right | Accent color, HUD size, and example health/mana values |
| **Arrange Elements**, in the right panel | Selected component coordinates, grid snapping, and layout reset |
| **Offline Material Art**, in the right panel | Surface material, frame detail, texture size, wear, opacity, and seed |
| **Refine One Piece**, in the right panel | **Regenerate selected** changes one kit component's artwork |
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
3. Under **Art Style**, choose **Illustrated fantasy** for smooth carved frames
   and layered ornaments, or **Medieval pixel** for blocky pixel artwork.
4. Under **Material**, choose **Wood**, **Stone**, or **Parchment**.
5. Under **Decoration**, choose **Simple**, **Balanced**, or **Rich**. This
   controls the amount of trim and ornamentation.
6. Choose **Target Resolution**, then click **Generate complete kit**.
7. Click **Menu**, **HUD**, and **Components** below the previews to inspect
   the three pages. These are parts of one kit, rather than alternative layouts.

![The two fantasy kit art styles](fantasy-kits.png)

| Page | Included examples |
| --- | --- |
| **Menu** | Title banner, menu panel, Continue/New journey/Settings/Exit buttons, character panel, and quest card |
| **HUD** | Health/mana bars, currency, minimap sample, objective panel, ability buttons, and quest-log button |
| **Components** | Framed panel, button-state examples, inventory slots, health/mana bars, and procedural icons |

Every image is drawn procedurally on your PC. Both styles work offline and
need no image downloads, AI service, account, or key. The controls and sample
screens form a starting kit; the app does not create gameplay logic.

### Refine one piece without replacing the kit

1. Open the page containing the piece you want to change.
2. Click it in the **large preview**. Its outline turns green and the right
   inspector shows its name. You select a whole component: for example,
   **Inventory** includes its slots and icons, and **Health** includes its frame,
   emblem, and bar artwork.
3. Under **Refine One Piece**, click **Regenerate selected**.
4. Inspect the new details. Click again for another result, or press **Ctrl+Z**
   to restore the previous artwork. **Ctrl+Shift+Z** or **Ctrl+Y** redoes it.

Regeneration changes that component's artwork, including its related states
and icons. Other components keep their artwork, and all pages keep their
positions and sizes. A component used on multiple pages, such as **Health**
or **TitleBanner**, receives the change on each of those pages.

Drag pieces and use their corner handles as described above. **Accent Color**,
**HUD Size**, and the live **Health**/**Mana** sliders work for kits too.
**Offline Material Art** is hidden in kit mode; the material and decoration
choices on the left supply the kit artwork.

Changing the kit style, material, decoration, or resolution marks the brief as
pending. **Generate complete kit** applies it by creating a fresh entire kit
and resetting the current arrangement, color, sizes, and sample values. Export
first if you want to keep the previous result. **Regenerate selected** is the
way to change one piece while preserving the current kit.

Buttons in the designer are selected and arranged with the mouse. Their game
actions become available after export, when you connect their native signals
in Godot. The **Components** page displays examples of the button states.
Pixel artwork uses nearest filtering. Fractional viewport scaling can make
pixel widths uneven; use whole-number game scaling for the sharpest pixel grid.

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
of them. `preset.json` records the complete kit seed and individual component
seeds, settings, positions, and sizes; it cannot yet be reopened in UI Forge.

Continue with [Add an exported fantasy kit to your game](godot-guide.md#add-an-exported-fantasy-kit-to-your-game).

## 8. Keep your work

Export before closing the app, generating another design, or clicking **New UI**.
Designs are currently held in memory, and reopening exported presets in UI Forge
is not implemented.
You can keep editing the exported scene and theme directly in Godot.

The menus, minimap, weapon values, timers, inventory, and ability slots contain
example data. They become functional when connected to your game's code. The central preview
background is illustrative and is not exported. Generation uses local templates.

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
| A kit exports pages you were not viewing | This is expected: every kit export includes Menu, HUD, and Components. |
| Menu buttons do not start a game | Export the kit, add the menu to your game, and connect its Button signals to your game code. |
| Export fails | Choose an existing writable folder, such as a folder in Documents. Read the status line for the specific error. |
| Map or ammo is not changing in a game | Those are sample controls; follow the Godot integration guide and connect gameplay data. |

To report a problem, open a
[GitHub issue](https://github.com/Ruslanf89/UI_Generator/issues) with your Windows
version, app version or download filename, exact error text, and steps that
caused it. Packaging was checked on Linux; native Windows launch has not yet
been validated in this project.
